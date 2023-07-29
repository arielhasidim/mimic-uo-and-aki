SELECT a.stay_id, 
  MAX(a.aki_stage_uo) max_stage, 
  IF(MAX(a.aki_stage_uo) = 0, 0, 1) aki_binary,
  COUNT(b.AKI_ID) aki_count
FROM `mimic_uo_and_aki.d3_kdigo_stages` a
LEFT JOIN mimic_uo_and_aki.e_aki_analysis b
  ON b.STAY_ID = a.stay_id
WHERE a.aki_stage_uo IS NOT NULL
GROUP BY a.stay_id
