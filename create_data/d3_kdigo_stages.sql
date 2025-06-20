CREATE OR REPLACE TABLE
  `mimic_uo_and_aki.d3_kdigo_stages` AS
  -- This query checks if the patient had AKI according to KDIGO 2012 AKI guideline.
  -- AKI is calculated every time a creatinine or urine output (UO) measurement occurs or renal replacement therapy (RRT) begins.
  -- Hourly UOs are imputed according to DOI:XXX
  -- KDIGO-UO are calculated twice:
  --  1. For an avarage UO rates per KG for 6, 12 and 24 hours (aki_stage_uo_mean)
  --  2. For hourly UO rates per KG in a consecutive manner for 6, 12 and 24 hours (aki_stage_uo_cons)
  -- Baseline creatinine is estimated by the lowest serum creatinine value in the last 7 days per patient.
  -- Creatinine stage 3 by RRT initiation was added. Since RRT can be also used in ESRD without AKI, 
  -- it has been looked at only if AKI has been diagnosed by creatinine in the last 48 hours.
  -- Fourth and final creatinine criterion for stage 3 in patients under the age of 18 has been left out (decrease in eGFR to <35 ml/min per 1.73 m2).
WITH
  cr_stg AS ( -- get creatinine stages
    SELECT
      cr.stay_id,
      cr.charttime,
      cr.creat_low_past_7day,
      cr.creat_low_past_48hr,
      cr.creat,
      CASE
      -- 3x baseline
        WHEN cr.creat >= (cr.creat_low_past_7day * 3.0) THEN 3
        -- *OR* cr reaches to >= 4.0 with associated increase
        WHEN cr.creat >= 4
        AND cr.creat_low_past_7day < 4
        -- For patients reaching Stage 3 by SCr >4.0 mg/dl
        -- require that the patient first achieve ... acute increase >= 0.3 within 48 hr
        -- *or* an increase of >= 1.5 times baseline
        AND (
          cr.creat - cr.creat_low_past_48hr >= 0.3
          OR cr.creat >= (1.5 * cr.creat_low_past_7day)
        ) THEN 3
        WHEN cr.creat >= (cr.creat_low_past_7day * 2.0) THEN 2
        WHEN cr.creat >= (cr.creat_low_past_48hr + 0.3) THEN 1
        WHEN cr.creat >= (cr.creat_low_past_7day * 1.5) THEN 1
        ELSE 0
      END AS aki_stage_creat
    FROM
      `mimic_uo_and_aki.d2_kdigo_creatinine` cr
  ),
  rrt_stg AS ( -- Stage 3 for RRT. Determined only if creatinine-AKI is present
    SELECT
      rrt.stay_id,
      rrt.charttime,
      rrt.dialysis_active,
      IF(rrt.dialysis_active = 1, 3, 0) AS aki_stage_rrt
    FROM
      `physionet-data.mimiciv_derived.rrt` rrt
      LEFT JOIN cr_stg ON cr_stg.stay_id = rrt.stay_id
      AND cr_stg.charttime < rrt.charttime
      AND DATETIME_ADD(cr_stg.charttime, INTERVAL 48 HOUR) > rrt.charttime
      -- AND cr_stg.aki_stage_creat > 0
    WHERE
      rrt.dialysis_active = 1
      AND cr_stg.aki_stage_creat > 0
    GROUP BY
      rrt.stay_id,
      rrt.charttime,
      rrt.dialysis_active,
      aki_stage_rrt
  ),
  uo_stg AS ( -- stages for UO
    SELECT
      uo.stay_id,
      uo.charttime,
      uo.weight_first,
      uo.uo_rt_kg_6hr,
      uo.uo_rt_kg_12hr,
      uo.uo_rt_kg_24hr,
      uo.uo_max_kg_6hr,
      uo.uo_max_kg_12hr,
      uo.uo_max_kg_24hr,
      CASE -- mean hourly UO meeting KDIGO criteria.
      -- require hourly urine output for every hour in the last 6 hours period at least.
        WHEN uo.uo_rt_kg_6hr IS NULL THEN NULL
        -- require the hourly UO rate to be calculated for every hour in the period.
        -- i.e. for uo rate over 24 hours, require documentation of UO rate for 24 hours.
        -- using avarage hourly rate, it means that individual hour can be bigger than the threshold
        WHEN uo.uo_rt_kg_24hr < 0.3
        AND uo.uo_rt_kg_6hr < 0.5 THEN 3
        WHEN uo.uo_rt_kg_12hr = 0
        AND uo.uo_rt_kg_6hr < 0.5 THEN 3 -- redundant
        WHEN uo.uo_rt_kg_12hr < 0.5
        AND uo.uo_rt_kg_6hr < 0.5 THEN 2
        WHEN uo.uo_rt_kg_6hr < 0.5 THEN 1
        ELSE 0
      END AS aki_stage_uo_mean,
      CASE -- UO meeting KDIGO criteria in each consecutive hour
      -- require hourly urine output for every hour in the last 6 hours period at least.
        WHEN uo.uo_max_kg_6hr IS NULL THEN NULL
        -- require the hourly UO rate to be calculated for every hour in the period.
        -- i.e. for uo rate over 24 hours, require documentation of UO rate for 24 hours.
        -- using maximum hourly rate, it means that all hours in interval must meat criteria consecutivly
        WHEN uo.uo_max_kg_24hr < 0.3
        AND uo.uo_max_kg_6hr < 0.5 THEN 3 -- redundant
        WHEN uo.uo_max_kg_12hr = 0
        AND uo.uo_max_kg_6hr < 0.5 THEN 3 -- redundant
        WHEN uo.uo_max_kg_12hr < 0.5
        AND uo.uo_max_kg_6hr < 0.5 THEN 2 -- redundant
        WHEN uo.uo_max_kg_6hr < 0.5 THEN 1
        ELSE 0
      END AS aki_stage_uo_cons
    FROM
      `mimic_uo_and_aki.d1_kdigo_uo` uo
  ),
  tm_stg AS ( -- get all chart times documented
    SELECT
      stay_id,
      charttime
    FROM
      cr_stg
    UNION DISTINCT
    SELECT
      stay_id,
      charttime
    FROM
      uo_stg
    UNION DISTINCT
    SELECT
      stay_id,
      charttime
    FROM
      rrt_stg
    GROUP BY
      stay_id,
      charttime
  )
SELECT
  ie.subject_id,
  ie.hadm_id,
  ie.stay_id,
  tm.charttime,
  IFNULL(w.WEIGHT_ADMIT, w.WEIGHT) weight_admit,
  cr.creat_low_past_7day,
  cr.creat_low_past_48hr,
  cr.creat,
  cr.aki_stage_creat,
  rrt.dialysis_active,
  rrt.aki_stage_rrt,
  uo.uo_rt_kg_6hr,
  uo.uo_rt_kg_12hr,
  uo.uo_rt_kg_24hr,
  uo.uo_max_kg_6hr,
  uo.uo_max_kg_12hr,
  uo.uo_max_kg_24hr,
  uo.aki_stage_uo_mean,
  uo.aki_stage_uo_cons,
  GREATEST( -- Classify AKI using both creatinine/urine output/active RRT criteria
    COALESCE(cr.aki_stage_creat, 0),
    COALESCE(uo.aki_stage_uo_mean, 0),
    COALESCE(rrt.aki_stage_rrt, 0)
  ) AS aki_stage_mean,
  GREATEST( -- Classify AKI using both creatinine/urine output/active RRT criteria
    COALESCE(cr.aki_stage_creat, 0),
    COALESCE(uo.aki_stage_uo_cons, 0),
    COALESCE(rrt.aki_stage_rrt, 0)
  ) AS aki_stage_cons
FROM
  `physionet-data.mimiciv_icu.icustays` ie
  LEFT JOIN tm_stg tm ON ie.stay_id = tm.stay_id -- get all possible charttimes as listed in tm_stg
  LEFT JOIN cr_stg cr ON ie.stay_id = cr.stay_id
  AND tm.charttime = cr.charttime
  LEFT JOIN uo_stg uo ON ie.stay_id = uo.stay_id
  AND tm.charttime = uo.charttime
  LEFT JOIN rrt_stg rrt ON ie.stay_id = rrt.stay_id
  AND tm.charttime = rrt.charttime
  LEFT JOIN `physionet-data.mimiciv_derived.first_day_weight` w ON w.STAY_ID = ie.STAY_ID