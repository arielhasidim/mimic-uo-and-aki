WITH kdigo AS (
  SELECT stay_id,
  MAX(aki_stage_uo) max_stage,
  IF(MAX(aki_stage_uo) = 0, 0, 1) aki_binary,
  COUNTIF(aki_stage_uo>0) / COUNT(aki_stage_uo) aki_portion
  FROM `mimic_uo_and_aki.d3_kdigo_stages` a
  WHERE a.aki_stage_uo IS NOT NULL
  GROUP BY stay_id
)

SELECT kdigo.stay_id, 
  kdigo.max_stage, 
  kdigo.aki_binary,
  kdigo.aki_portion,
  COUNT(a.AKI_ID) aki_count,
  AVG(DATETIME_DIFF(a.AKI_STOP, a.AKI_START, MINUTE) / 60) aki_mean_duration,
  SUM(DATETIME_DIFF(a.AKI_STOP, a.AKI_START, MINUTE) / 60 / 24) aki_total_time
FROM kdigo
LEFT JOIN `mimic_uo_and_aki.e_aki_analysis` a
  ON a.STAY_ID = kdigo.stay_id
WHERE kdigo.STAY_ID IN (
        SELECT 
            STAY_ID
        FROM
            `mimic_uo_and_aki.b_uo_rate`
        WHERE
            TIME_INTERVAL IS NOT NULL
    )
GROUP BY kdigo.stay_id, kdigo.max_stage, kdigo.aki_binary, kdigo.aki_portion
