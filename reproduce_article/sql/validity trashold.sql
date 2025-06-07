WITH
  stays_services AS (
    -- Adding ICU type by looking into services
    SELECT
      a.STAY_ID,
      ARRAY_AGG(
        c.curr_service
        ORDER BY
          c.transfertime DESC
        LIMIT
          1
      ) [OFFSET(0)] AS SERVICE
    FROM
      `mimic_uo_and_aki.a_urine_output_raw` a
      LEFT JOIN `physionet-data.mimiciv_hosp.services` c ON c.hadm_id = a.HADM_ID
      AND c.transfertime < DATETIME_ADD(a.CHARTTIME, INTERVAL 1 HOUR)
    GROUP BY
      a.STAY_ID
  )
  -- select eligible ICU stays
SELECT
  a.STAY_ID,
  a.WEIGHT_ADMIT,
  c.FIRST_STAGE_UO_CONS AS FIRST_STAGE_NEW_CONS,
  c.AKI_STAGE_UO_CONS AS MAX_STAGE_NEW_CONS,
  d3.FIRST_STAGE_UO_CONS AS FIRST_STAGE_NEW_CONS_95_20,
  d3.AKI_STAGE_UO_CONS AS MAX_STAGE_NEW_CONS_95_20,
  d4.FIRST_STAGE_UO_CONS AS FIRST_STAGE_NEW_CONS_99_20,
  d4.AKI_STAGE_UO_CONS AS MAX_STAGE_NEW_CONS_99_20,
  IFNULL(DATE_DIFF(b.dod, a.intime, DAY), 365) AS FOLLOWUP_DAYS,
  IF(dod IS NOT NULL, 1, 0) AS DEATH_FLAG
FROM
  (
    SELECT
      ARRAY_AGG(
        a.STAY_ID
        ORDER BY
          a.INTIME ASC
        LIMIT
          1
      ) [OFFSET(0)] STAY_ID,
      ARRAY_AGG(
        a.HADM_ID
        ORDER BY
          a.INTIME ASC
        LIMIT
          1
      ) [OFFSET(0)] HADM_ID,
      a.SUBJECT_ID,
      a.INTIME,
      IFNULL(w.WEIGHT_ADMIT, w.WEIGHT) WEIGHT_ADMIT
    FROM
      `physionet-data.mimiciv_icu.icustays` a
      LEFT JOIN `physionet-data.mimiciv_derived.first_day_weight` w ON w.STAY_ID = a.STAY_ID
    GROUP BY
      SUBJECT_ID,
      INTIME,
      w.WEIGHT_ADMIT,
      w.WEIGHT
  ) a
  LEFT JOIN `physionet-data.mimiciv_hosp.patients` b ON b.SUBJECT_ID = a.SUBJECT_ID
  LEFT JOIN (
    SELECT
      a.STAY_ID,
      MAX(a.AKI_STAGE_UO_CONS) AKI_STAGE_UO_CONS,
      ARRAY_AGG(
        a.AKI_STAGE_UO_CONS IGNORE NULLS
        ORDER BY
          a.CHARTTIME ASC
        LIMIT
          1
      ) [OFFSET(0)] FIRST_STAGE_UO_CONS
    FROM
      `mimic_uo_and_aki.d3_kdigo_stages` a
    LEFT JOIN  (SELECT STAY_ID, MIN(CHARTTIME) CHARTIME FROM `mimic_uo_and_aki.a_urine_output_raw` GROUP BY STAY_ID)
      AS b ON b.STAY_ID = a.STAY_ID
    WHERE a.CHARTTIME < DATETIME_ADD(b.CHARTIME, INTERVAL 72 HOUR)
    GROUP BY
      STAY_ID
  ) c ON c.STAY_ID = a.STAY_ID
  LEFT JOIN (
    SELECT
      a.STAY_ID,
      MAX(a.AKI_STAGE_UO_CONS) AKI_STAGE_UO_CONS,
      ARRAY_AGG(
        a.AKI_STAGE_UO_CONS IGNORE NULLS
        ORDER BY
          a.CHARTTIME ASC
        LIMIT
          1
      ) [OFFSET(0)] FIRST_STAGE_UO_CONS
    FROM
      `mimic_uo_and_aki.d3_kdigo_stages_9520_temp` a
    LEFT JOIN  (SELECT STAY_ID, MIN(CHARTTIME) CHARTIME FROM `mimic_uo_and_aki.a_urine_output_raw` GROUP BY STAY_ID)
      AS b ON b.STAY_ID = a.STAY_ID
    WHERE a.CHARTTIME < DATETIME_ADD(b.CHARTIME, INTERVAL 72 HOUR)
    GROUP BY
      STAY_ID
  ) d3 ON d3.STAY_ID = a.STAY_ID
  LEFT JOIN (
    SELECT
      a.STAY_ID,
      MAX(a.AKI_STAGE_UO_CONS) AKI_STAGE_UO_CONS,
      ARRAY_AGG(
        a.AKI_STAGE_UO_CONS IGNORE NULLS
        ORDER BY
          a.CHARTTIME ASC
        LIMIT
          1
      ) [OFFSET(0)] FIRST_STAGE_UO_CONS
    FROM
      `mimic_uo_and_aki.d3_kdigo_stages_9920_temp` a
    LEFT JOIN  (SELECT STAY_ID, MIN(CHARTTIME) CHARTIME FROM `mimic_uo_and_aki.a_urine_output_raw` GROUP BY STAY_ID)
      AS b ON b.STAY_ID = a.STAY_ID
    WHERE a.CHARTTIME < DATETIME_ADD(b.CHARTIME, INTERVAL 72 HOUR)
    GROUP BY
      STAY_ID
  ) d4 ON d4.STAY_ID = a.STAY_ID
  LEFT JOIN (
    SELECT
      a.STAY_ID,
      MAX(a.AKI_STAGE_UO_CONS) AKI_STAGE_UO_CONS,
      ARRAY_AGG(
        a.AKI_STAGE_UO_CONS IGNORE NULLS
        ORDER BY
          a.CHARTTIME ASC
        LIMIT
          1
      ) [OFFSET(0)] FIRST_STAGE_UO_CONS
    FROM
      `mimic_uo_and_aki.d3_kdigo_stages_9920_temp` a
    LEFT JOIN  (SELECT STAY_ID, MIN(CHARTTIME) CHARTIME FROM `mimic_uo_and_aki.a_urine_output_raw` GROUP BY STAY_ID)
      AS b ON b.STAY_ID = a.STAY_ID
    WHERE a.CHARTTIME < DATETIME_ADD(b.CHARTIME, INTERVAL 72 HOUR)
    GROUP BY
      STAY_ID
  ) d5 ON d5.STAY_ID = a.STAY_ID
WHERE
  -- First ICU stay for patient
  a.STAY_ID IN (
    SELECT
      ARRAY_AGG(
        STAY_ID
        ORDER BY
          intime ASC
        LIMIT
          1
      ) [OFFSET(0)] FIRST_STAY_ID_IN_PATIENT
    FROM
      `physionet-data.mimiciv_icu.icustays`
    GROUP BY
      subject_id
  )
  -- Exclude all stays with ureteral stent or GU irrigation 
  -- (See https://github.com/MIT-LCP/mimic-code/issues/745 for GU irrig.)
  AND a.STAY_ID NOT IN (
    SELECT
      STAY_ID
    FROM
      `physionet-data.mimiciv_icu.outputevents`
    WHERE
      ITEMID IN (227488, 227489, 226558, 226557)
    GROUP BY
      STAY_ID
  )
  -- ICU stay type inclusion by service
  AND a.STAY_ID IN (
    SELECT
      STAY_ID
    FROM
      stays_services
    WHERE
      SERVICE IN (
        'MED',
        'TSURG',
        'CSURG',
        'CMED',
        'NMED',
        'OMED',
        'TRAUM',
        'SURG',
        'NSURG',
        'ORTHO',
        'VSURG',
        'ENT',
        'PSURG',
        'GU'
      )
  )