WITH stays_services AS (
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
SELECT
  *
FROM
  `mimic_uo_and_aki.a_urine_output_raw`
WHERE
  STAY_ID NOT IN (
    SELECT
      STAY_ID
    FROM
      `physionet-data.mimiciv_icu.outputevents`
    WHERE
      ITEMID IN (226558, 226557, 227488, 227489)
    GROUP BY
      STAY_ID
  )
  AND STAY_ID IN (
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
  AND NOT (
    VALUE > 5000
    OR VALUE < 0
  )
