WITH
    stays_services AS (
        -- Adding ICU type by looking into services
        SELECT
            a.hadm_id,
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
            a.hadm_id,
            a.STAY_ID
    ),
    creatinine AS (
          SELECT
            ie.hadm_id
            , ie.stay_id
            , le.charttime
            , AVG(le.valuenum) AS creat
        FROM `physionet-data.mimiciv_icu.icustays` ie
        LEFT JOIN `physionet-data.mimiciv_hosp.labevents` le
            ON ie.subject_id = le.subject_id
                AND le.itemid = 50912
                AND le.valuenum IS NOT NULL
                AND le.valuenum <= 150
                AND le.charttime >= DATETIME_TRUNC(ie.intime, DAY)
                AND le.charttime <= ie.outtime
        GROUP BY ie.hadm_id, ie.stay_id, le.charttime
    )
SELECT
    a.hadm_id,
    a.STAY_ID,
    a.SERVICE,
    b.uo_count,
    c.gender,
    c.hospital_expire_flag,
    c.admission_age,
    c.race,
    c.los_icu icu_days,
    c.los_hospital hospital_days,
    IFNULL(d.weight_admit, d.weight) weight_admit,
    e.height_first,
    f.SOFA sofa_first_day,
    g.apsiii,
    h.charlson_comorbidity_index,
    i.creat_first,
    i3.creat_peak_72,
    i2.creat_last,
    n.kdigo_cr_max,
    j.ckd,
    k.rrt_binary,
    l.dm,
    m.sapsii
FROM
    stays_services a
    LEFT JOIN (
        SELECT
            STAY_ID,
            COUNT(VALUE) uo_count
        FROM
            `mimic_uo_and_aki.a_urine_output_raw`
        WHERE
            VALUE <= 5000
            AND VALUE >= 0
        GROUP BY
            STAY_ID
    ) b ON b.STAY_ID = a.STAY_ID
    LEFT JOIN `physionet-data.mimiciv_derived.icustay_detail` c ON c.STAY_ID = a.STAY_ID
    LEFT JOIN `physionet-data.mimiciv_derived.first_day_weight` d ON d.STAY_ID = a.STAY_ID
    LEFT JOIN (
        SELECT
            stay_id,
            ARRAY_AGG(
                height
                ORDER BY
                    charttime ASC
                LIMIT
                    1
            ) [OFFSET(0)] height_first
        FROM
            `physionet-data.mimiciv_derived.height`
        WHERE
            height IS NOT NULL
        GROUP BY
            stay_id
    ) e ON e.stay_id = a.stay_id
    LEFT JOIN `physionet-data.mimiciv_derived.first_day_sofa` f ON f.stay_id = a.stay_id
    LEFT JOIN `physionet-data.mimiciv_derived.apsiii` g ON g.stay_id = a.stay_id
    LEFT JOIN `physionet-data.mimiciv_derived.charlson` h ON h.hadm_id = a.hadm_id
    LEFT JOIN (
        SELECT
            stay_id,
            ARRAY_AGG(
                creat
                ORDER BY
                    charttime ASC
                LIMIT
                    1
            ) [OFFSET(0)] creat_first
        FROM creatinine
        GROUP BY
            stay_id
    ) i ON i.stay_id = a.stay_id
    LEFT JOIN (
        SELECT
            stay_id,
            ARRAY_AGG(
                creat
                ORDER BY
                    charttime DESC
                LIMIT
                    1
            ) [OFFSET(0)] creat_last
        FROM creatinine
        GROUP BY
            stay_id
    ) i2 ON i2.stay_id = a.stay_id
    LEFT JOIN (
        SELECT
            a.stay_id,
            MAx(a.creat) creat_peak_72
        FROM creatinine a
            LEFT JOIN  (SELECT STAY_ID, MIN(CHARTTIME) CHARTIME FROM `mimic_uo_and_aki.a_urine_output_raw` GROUP BY STAY_ID)
              AS b ON b.STAY_ID = a.STAY_ID
        WHERE
            a.creat IS NOT NULL
            AND a.CHARTTIME < DATETIME_ADD(b.CHARTIME, INTERVAL 72 HOUR)
        GROUP BY
            a.stay_id
    ) i3 ON i3.stay_id = a.stay_id
    LEFT JOIN (
        SELECT
            hadm_id,
            MAX(
                CASE
                    WHEN (
                        SUBSTR(icd_code, 1, 3) = '585'
                        AND icd_version = 9
                    )
                    OR (
                        SUBSTR(icd_code, 1, 3) = 'N18'
                        AND icd_version = 10
                    ) THEN 1
                    ELSE 0
                END
            ) AS ckd
        FROM
            `physionet-data.mimiciv_hosp.diagnoses_icd`
        GROUP BY
            hadm_id
    ) j ON j.hadm_id = a.hadm_id
    LEFT JOIN (
        SELECT
            a.HADM_ID,
            IF(COUNT(b.dialysis_active) > 0, 1, 0) rrt_binary
        FROM
            `physionet-data.mimiciv_icu.icustays` a
            LEFT JOIN `physionet-data.mimiciv_derived.rrt` b ON b.STAY_ID = a.STAY_ID
        GROUP BY
            HADM_ID
    ) k ON k.hadm_id = a.hadm_id
    LEFT JOIN (
        SELECT
            hadm_id,
            MAX(
                CASE
                    WHEN SUBSTR(icd9_code, 1, 4) IN ('2500', '2501', '2502', '2503', '2508', '2509')
                    OR SUBSTR(icd10_code, 1, 4) IN (
                        'E100',
                        'E101',
                        'E106',
                        'E108',
                        'E109',
                        'E110',
                        'E111',
                        'E116',
                        'E118',
                        'E119',
                        'E120',
                        'E121',
                        'E126',
                        'E128',
                        'E129',
                        'E130',
                        'E131',
                        'E136',
                        'E138',
                        'E139',
                        'E140',
                        'E141',
                        'E146',
                        'E148',
                        'E149'
                    ) THEN 1
                    ELSE 0
                END
            ) AS dm
        FROM
            (
                SELECT
                    hadm_id,
                    CASE
                        WHEN icd_version = 9 THEN icd_code
                        ELSE NULL
                    END AS icd9_code,
                    CASE
                        WHEN icd_version = 10 THEN icd_code
                        ELSE NULL
                    END AS icd10_code
                FROM
                    `physionet-data.mimiciv_hosp.diagnoses_icd`
            )
        GROUP BY
            hadm_id
    ) l ON l.hadm_id = a.hadm_id
    LEFT JOIN (
        SELECT
            a.stay_id,
            ARRAY_AGG(
                b.sapsii
                ORDER BY
                    b.starttime DESC
                LIMIT
                    1
            ) [OFFSET(0)] AS sapsii
        FROM
            `physionet-data.mimiciv_icu.icustays` a
            LEFT JOIN `physionet-data.mimic_derived.sapsii` b ON b.STAY_ID = a.STAY_ID
        WHERE
            b.sapsii IS NOT NULL
        GROUP BY
            a.stay_id
    ) m ON m.stay_id = a.stay_id
    LEFT JOIN (
        SELECT a.stay_id,
            MAX(a.aki_stage_creat) kdigo_cr_max
        FROM `mimic_uo_and_aki.d3_kdigo_stages` a
        LEFT JOIN  (SELECT STAY_ID, MIN(CHARTTIME) CHARTIME FROM `mimic_uo_and_aki.a_urine_output_raw` GROUP BY STAY_ID)
              AS b ON b.STAY_ID = a.STAY_ID
        WHERE
            a.creat IS NOT NULL
            AND a.CHARTTIME < DATETIME_ADD(b.CHARTIME, INTERVAL 72 HOUR)
        GROUP BY a.stay_id
    ) n ON n.stay_id = a.stay_id
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
    AND a.STAY_ID NOT IN (
        SELECT
            STAY_ID
        FROM
            `physionet-data.mimiciv_icu.outputevents`
        WHERE
            ITEMID IN (226558, 226557, 227488, 227489)
        GROUP BY
            STAY_ID
    )
    AND a.STAY_ID IN (
        SELECT
            STAY_ID
        FROM
            `mimic_uo_and_aki.b_uo_rate`
        WHERE
            TIME_INTERVAL IS NOT NULL
    )