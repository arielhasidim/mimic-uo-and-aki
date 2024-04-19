CREATE TEMP FUNCTION GREATEST_ARRAY(arr ANY TYPE) AS ((
    SELECT MAX(a) FROM UNNEST(arr) a WHERE a is not NULL
));

WITH
  HADM_AKI_COUNT AS (
    SELECT
      aa.AKI_ID,
      COUNT(bb.AKI_ID) HADM_RESOLVED_UO_AKI_PRE
    FROM
      `mimic_uo_and_aki.e_aki_analysis` aa
      LEFT JOIN `mimic_uo_and_aki.e_aki_analysis` bb ON bb.HADM_ID = aa.HADM_ID
      AND bb.AKI_STOP < aa.AKI_START
    GROUP BY
      aa.AKI_ID
  ),
  HADM_LATEST_UO AS (
    SELECT
      HADM_ID,
      MAX(CHARTTIME) LATEST_POSITIVE_UO
    FROM
      `mimic_uo_and_aki.a_urine_output_raw`
    WHERE
      VALUE > 0
    GROUP BY
      HADM_ID
  ),
  HADM_LATEST_VITAL_SIGN AS (
    SELECT
      HADM_ID,
      MAX(CHARTTIME) LATEST_POSITIVE_VITAL_SIGN
    FROM
      `physionet-data.mimiciv_icu.chartevents`
    WHERE
      ITEMID IN (
        220045, -- Heart Rate(bpm)
        220210, -- Respiratory Rate (insp/min)
        220277, -- O2 saturation pulseoxymetry (%)
        220179, 220180, 220181, -- Non Invasive Blood Pressure systolic/diastolic/mean (mmHg)
        220052, 220051, 220050, -- Arterial Blood Pressure mean/systolic/diastolic (mmHg)
        223761, -- Temperature Fahrenheit (°F)
        220074 -- Central Venous Pressure (mmHg)
      )
      AND CASE
        WHEN ITEMID = 223761 THEN VALUENUM > 86
        WHEN ITEMID = 220277 THEN VALUENUM > 50
        WHEN ITEMID IN (
          220179,
          220180,
          220181,
          220052,
          220051,
          220050,
          220074
        ) THEN VALUENUM > 20
        ELSE VALUENUM > 0
      END
    GROUP BY
      HADM_ID
  ),
  HADM_DEATH_OR_DISCHARGE_TIME AS (
    SELECT
      a.HADM_ID,
      GREATEST_ARRAY(
        [a.DEATHTIME,
        a.DISCHTIME,
        b.LATEST_POSITIVE_UO,
        c.LATEST_POSITIVE_VITAL_SIGN]
      ) DEATH_OR_DISCHARGE_TIME
    FROM
      `physionet-data.mimiciv_hosp.admissions` a
      LEFT JOIN HADM_LATEST_UO b ON b.HADM_ID = a.HADM_ID
      LEFT JOIN HADM_LATEST_VITAL_SIGN c ON c.HADM_ID = a.HADM_ID
  )
SELECT
  a.AKI_ID,
  a.STAY_ID,
  a.HADM_ID,
  a.SUBJECT_ID,
  a.AKI_START,
  d.DEATH_OR_DISCHARGE_TIME DEATH_OR_DISCH,
  DATETIME_DIFF(
    d.DEATH_OR_DISCHARGE_TIME,
    a.AKI_START,
    HOUR
  ) / 24 FIRST_AKI_TO_DEATH_OR_DISCH,
  c.hospital_expire_flag HADM_DEATH_FLAG,
  a.WORST_STAGE PEAK_UO_STAGE,
  a.NO_START,
  b.HADM_RESOLVED_UO_AKI_PRE
FROM
  `mimic_uo_and_aki.e_aki_analysis` a
  LEFT JOIN HADM_AKI_COUNT b ON b.AKI_ID = a.AKI_ID
  LEFT JOIN `physionet-data.mimiciv_hosp.admissions` c ON c.hadm_id = a.HADM_ID
  LEFT JOIN HADM_DEATH_OR_DISCHARGE_TIME d ON d.HADM_ID = a.HADM_ID