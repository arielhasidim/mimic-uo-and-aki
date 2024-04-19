WITH
    creat AS (
        SELECT
            ie.SUBJECT_ID,
            ie.HADM_ID,
            ie.STAY_ID,
            le.CHARTTIME,
            AVG(le.valuenum) AS CREAT
        FROM
            `physionet-data.mimiciv_icu.icustays` ie
            LEFT JOIN `physionet-data.mimiciv_hosp.labevents` le ON ie.subject_id = le.subject_id
        WHERE
            ITEMID = 50912
            AND VALUENUM IS NOT NULL
            AND VALUENUM <= 150
            AND VALUENUM > 0
        GROUP BY
            ie.subject_id,
            ie.hadm_id,
            ie.stay_id,
            le.charttime
    ),
    cr7 AS (
        SELECT
            a.STAY_ID,
            a.CHARTTIME,
            MIN(b.CREAT) CREAT_LOWEST7
        FROM
            creat a
            LEFT JOIN creat b ON b.subject_id = a.subject_id
            AND b.charttime <= a.charttime
            AND b.charttime >= DATETIME_ADD(a.charttime, INTERVAL -7 DAY)
        GROUP BY
            a.STAY_ID,
            a.CHARTTIME
    )
SELECT
    a.SUBJECT_ID,
    a.HADM_ID,
    a.STAY_ID,
    a.CHARTTIME,
    a.CREAT,
    b.SCR_BASELINE,
    c.CREAT_LOWEST7,
    a.CREAT - b.SCR_BASELINE AS CREAT_BASLINE_DIFF,
    a.CREAT / b.SCR_BASELINE AS CREAT_BASLINE_RATIO,
    a.CREAT - c.CREAT_LOWEST7 AS CREAT_LOWEST7_DIFF,
    a.CREAT / c.CREAT_LOWEST7 AS CREAT_LOWEST7_RATIO
FROM
    creat a
    LEFT JOIN `physionet-data.mimiciv_derived.creatinine_baseline` b ON b.HADM_ID = a.HADM_ID
    LEFT JOIN cr7 c ON c.STAY_ID = a.STAY_ID
    AND c.charttime = a.charttime
WHERE
    NOT (a.CREAT < b.SCR_BASELINE)
