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
  ),
  count_compartments AS (
    SELECT
      STAY_ID,
      (
        NON_BLADDER + BLADDER
      ) compartment_count
    FROM
      (
        SELECT
          a.STAY_ID,
          COUNT(DISTINCT b.ITEMID) NON_BLADDER,
          IF(SUM(c.ITEMID) IS NULL, 0, 1) AS BLADDER,
        FROM
          `physionet-data.mimiciv_icu.icustays` a
          LEFT JOIN `mimic_uo_and_aki.a_urine_output_raw` b ON b.STAY_ID = a.STAY_ID
          AND b.ITEMID IN (226565, 226564, 226584)
          LEFT JOIN `mimic_uo_and_aki.a_urine_output_raw` c ON c.STAY_ID = a.STAY_ID
          AND c.ITEMID NOT IN (226565, 226564, 226584)
        GROUP BY
          a.STAY_ID
      )
  )
  -- select eligible ICU stays
SELECT
  a.STAY_ID,
  a.HADM_ID,
  a.SUBJECT_ID,
  c.FIRST_STAGE_UO AS FIRST_STAGE_OLD,
  c.AKI_STAGE_UO AS MAX_STAGE_OLD,
  d.FIRST_STAGE_UO_CONS AS FIRST_STAGE_NEW_CONS,
  d.AKI_STAGE_UO_CONS AS MAX_STAGE_NEW_CONS,
  d.FIRST_POSITIVE_STAGE_UO_CONS_TIME,
  d.FIRST_POSITIVE_STAGE_UO_MEAN_TIME,
  d.FIRST_STAGE_UO_MEAN AS FIRST_STAGE_NEW_MEAN,
  d.AKI_STAGE_UO_MEAN AS MAX_STAGE_NEW_MEAN,
  IFNULL(DATETIME_DIFF(IFNULL(f.deathtime, b.dod), a.intime, DAY), 365) AS FOLLOWUP_DAYS,
  IF(dod IS NOT NULL, 1, 0) AS DEATH_FLAG,
  COMPARTMENT_COUNT
FROM
  (
    SELECT
      ARRAY_AGG(
        STAY_ID
        ORDER BY
          INTIME ASC
        LIMIT
          1
      ) [OFFSET(0)] STAY_ID,
      ARRAY_AGG(
        HADM_ID
        ORDER BY
          INTIME ASC
        LIMIT
          1
      ) [OFFSET(0)] HADM_ID,
      SUBJECT_ID,
      INTIME
    FROM
      `physionet-data.mimiciv_icu.icustays`
    GROUP BY
      SUBJECT_ID,
      INTIME
  ) a
  LEFT JOIN `physionet-data.mimiciv_hosp.patients` b ON b.SUBJECT_ID = a.SUBJECT_ID
  LEFT JOIN (
    SELECT
      a.STAY_ID,
      MAX(a.AKI_STAGE_UO) AKI_STAGE_UO,
      ARRAY_AGG(
        a.AKI_STAGE_UO IGNORE NULLS
        ORDER BY
          a.CHARTTIME ASC
        LIMIT
          1
      ) [OFFSET(0)] FIRST_STAGE_UO
    FROM
      `physionet-data.mimiciv_derived.kdigo_stages` a
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
      MAX(a.AKI_STAGE_UO_MEAN) AKI_STAGE_UO_MEAN,
      ARRAY_AGG(
        a.AKI_STAGE_UO_CONS IGNORE NULLS
        ORDER BY
          a.CHARTTIME ASC
        LIMIT
          1
      ) [OFFSET(0)] FIRST_STAGE_UO_CONS,
      ARRAY_AGG(
        a.AKI_STAGE_UO_MEAN IGNORE NULLS
        ORDER BY
          a.CHARTTIME ASC
        LIMIT
          1
      ) [OFFSET(0)] FIRST_STAGE_UO_MEAN,
      min(b.CHARTTIME) FIRST_POSITIVE_STAGE_UO_CONS_TIME,
      min(d.CHARTTIME) FIRST_POSITIVE_STAGE_UO_MEAN_TIME
    FROM
      `mimic_uo_and_aki.d3_kdigo_stages` a
    LEFT JOIN  (SELECT STAY_ID, MIN(CHARTTIME) CHARTIME FROM `mimic_uo_and_aki.a_urine_output_raw` GROUP BY STAY_ID)
      AS C ON C.STAY_ID = a.STAY_ID
    LEFT JOIN `mimic_uo_and_aki.d3_kdigo_stages` b
      ON b.stay_id = a.STAY_ID AND b.AKI_STAGE_UO_CONS > 0 AND b.CHARTTIME < DATETIME_ADD(C.CHARTIME, INTERVAL 72 HOUR)
    LEFT JOIN `mimic_uo_and_aki.d3_kdigo_stages` d
      ON d.stay_id = a.STAY_ID AND d.AKI_STAGE_UO_MEAN > 0 AND d.CHARTTIME < DATETIME_ADD(C.CHARTIME, INTERVAL 72 HOUR)
    WHERE a.CHARTTIME < DATETIME_ADD(C.CHARTIME, INTERVAL 72 HOUR)
    GROUP BY
      STAY_ID
  ) d ON d.STAY_ID = a.STAY_ID
  LEFT JOIN count_compartments e ON e.STAY_ID = a.STAY_ID
  LEFT JOIN `physionet-data.mimiciv_hosp.admissions` f ON f.HADM_ID = a.HADM_ID
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