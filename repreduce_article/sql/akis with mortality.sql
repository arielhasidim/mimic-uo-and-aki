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
  )
SELECT
  a.AKI_ID,
  a.STAY_ID,
  a.HADM_ID,
  a.SUBJECT_ID,
  a.AKI_START,
  IFNULL(c.deathtime, c.dischtime) DEATH_OR_DISCH,
  DATETIME_DIFF(
    IFNULL(c.deathtime, c.dischtime),
    a.AKI_START,
    HOUR
  ) / 24  FIRST_AKI_TO_DEATH_OR_DISCH,
  c.hospital_expire_flag HADM_DEATH_FLAG,
  a.WORST_STAGE PEAK_UO_STAGE,
  a.NO_START,
  b.HADM_RESOLVED_UO_AKI_PRE
FROM
  `mimic_uo_and_aki.e_aki_analysis` a
  LEFT JOIN HADM_AKI_COUNT b ON b.AKI_ID = a.AKI_ID
  LEFT JOIN `physionet-data.mimiciv_hosp.admissions` c ON c.hadm_id = a.HADM_ID
