WITH stays_services AS (
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
    d.weight_admit,
    e.height_first,
    f.SOFA sofa_first_day,
    g.charlson_comorbidity_index,
    h.creat_first,
    i.ckd,
    i.scr_baseline,
    j.rrt_binary
FROM
    stays_services a
    LEFT JOIN (
        SELECT
            STAY_ID,
            COUNT(VALUE) uo_count
        FROM
            `mimic_uo_and_aki.a_urine_output_raw`
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
    LEFT JOIN `physionet-data.mimiciv_derived.charlson` g ON g.hadm_id = a.hadm_id
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
        FROM
            `physionet-data.mimiciv_derived.kdigo_creatinine`
        WHERE
            creat IS NOT NULL
        GROUP BY
            stay_id
    ) h ON h.stay_id = a.stay_id
    LEFT JOIN `physionet-data.mimiciv_derived.creatinine_baseline` i ON i.hadm_id = a.hadm_id
    LEFT JOIN (
        SELECT
            a.HADM_ID,
            IF(COUNT(b.dialysis_active) > 0, 1, 0) rrt_binary
        FROM
            `physionet-data.mimiciv_icu.icustays` a
            LEFT JOIN `physionet-data.mimiciv_derived.rrt` b ON b.STAY_ID = a.STAY_ID
        GROUP BY
            HADM_ID
    ) j ON j.hadm_id = a.hadm_id
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
