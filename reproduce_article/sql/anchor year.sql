SELECT a.HADM_ID,
    EXTRACT(YEAR FROM a.admittime) - b.anchor_year + CAST(SUBSTR(anchor_year_group, 0, 4) AS INT64) AS ANCHOR_START,
    EXTRACT(YEAR FROM a.admittime) - b.anchor_year + CAST(SUBSTR(anchor_year_group, -4) AS INT64) AS ANCHOR_END
FROM `physionet-data.mimiciv_hosp.admissions` a
left join `physionet-data.mimiciv_hosp.patients` b on b.subject_id = a.subject_id