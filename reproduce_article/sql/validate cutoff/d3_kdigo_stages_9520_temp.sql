CREATE OR REPLACE TABLE
  `mimic_uo_and_aki.d3_kdigo_stages_9520_temp` AS
WITH
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
        AND uo.uo_rt_kg_6hr < 0.5 THEN 3
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
        AND uo.uo_max_kg_6hr < 0.5 THEN 3
        WHEN uo.uo_max_kg_12hr = 0
        AND uo.uo_max_kg_6hr < 0.5 THEN 3
        WHEN uo.uo_max_kg_12hr < 0.5
        AND uo.uo_max_kg_6hr < 0.5 THEN 2
        WHEN uo.uo_max_kg_6hr < 0.5 THEN 1
        ELSE 0
      END AS aki_stage_uo_cons
    FROM
      `mimic_uo_and_aki.d1_kdigo_uo_9520_temp` uo
  ),
  tm_stg AS ( -- get all chart times documented
    SELECT
      stay_id,
      charttime
    FROM
      uo_stg
  )
SELECT
  ie.subject_id,
  ie.hadm_id,
  ie.stay_id,
  tm.charttime,
  uo.uo_rt_kg_6hr,
  uo.uo_rt_kg_12hr,
  uo.uo_rt_kg_24hr,
  uo.uo_max_kg_6hr,
  uo.uo_max_kg_12hr,
  uo.uo_max_kg_24hr,
  uo.aki_stage_uo_mean,
  uo.aki_stage_uo_cons,
FROM
  `physionet-data.mimiciv_icu.icustays` ie
  LEFT JOIN tm_stg tm ON ie.stay_id = tm.stay_id -- get all possible charttimes as listed in tm_stg
  LEFT JOIN uo_stg uo ON ie.stay_id = uo.stay_id
  AND tm.charttime = uo.charttime