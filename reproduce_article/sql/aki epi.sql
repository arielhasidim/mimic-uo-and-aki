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
    )
    -- select eligible ICU stays
SELECT
    a.STAY_ID,
    b.first_kdigo_uo,
    b.first_aki_id,
    b.max_uo_stage
FROM
    `physionet-data.mimiciv_icu.icustays` a
    LEFT JOIN (
        SELECT
            a.stay_id,
            ARRAY_AGG(
                a.aki_stage_uo IGNORE NULLS
                ORDER BY
                    a.charttime ASC
                LIMIT
                    1
            ) [OFFSET(0)] first_kdigo_uo,
            ARRAY_AGG(
                c.AKI_ID IGNORE NULLS
                ORDER BY
                    c.AKI_START ASC
                LIMIT
                    1
            ) [OFFSET(0)] first_aki_id,
            ARRAY_AGG(
                c.WORST_STAGE IGNORE NULLS
                ORDER BY
                    c.AKI_START ASC
                LIMIT
                    1
            ) [OFFSET(0)] max_uo_stage
        FROM
            `mimic_uo_and_aki.d3_kdigo_stages` a
            LEFT JOIN (
                SELECT
                    stay_id,
                    MIN(CHARTTIME) AS first_record
                FROM
                    `mimic_uo_and_aki.a_urine_output_raw`
                GROUP BY
                    stay_id
            ) b ON b.stay_id = a.stay_id
            LEFT JOIN `mimic_uo_and_aki.e_aki_analysis` c ON c.stay_id = a.stay_id
            AND c.AKI_START <= DATETIME_ADD(b.first_record, INTERVAL 24 HOUR)
            AND no_start = 0
        WHERE
            a.charttime <= DATETIME_ADD(b.first_record, INTERVAL 24 HOUR)
        GROUP BY
            stay_id
    ) b ON b.STAY_ID = a.STAY_ID
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
    AND first_kdigo_uo IS NOT NULL
