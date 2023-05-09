CREATE OR REPLACE TABLE `mimic_uo_and_aki.a_urine_output_raw` AS

WITH
    uo AS (
        -- Original query from official MIMIC's repository in permalink: 
        -- https://github.com/MIT-LCP/mimic-code/blob/892c21cec2a5ea046d432148d2e8d5e16d2781f4/mimic-iv/concepts/measurement/urine_output.sql
        SELECT
            SUBJECT_ID, -- Added to the original query
            HADM_ID, -- Added to the original query
            oe.stay_id STAY_ID,
            oe.charttime CHARTTIME,
            -- "volumes associated with urine output ITEMIDs
            -- note we consider input of GU irrigant AS a negative volume
            -- GU irrigant volume IN usually has a corresponding volume out
            -- so the net is often 0, despite large irrigant volumes"
            -- (the comment above is from the original query, 
            -- later in our analysis ICU stays with GU irrigation will be excluded)
            CASE
                WHEN oe.itemid = 227488
                AND oe.value > 0 THEN -1 * oe.value
                ELSE oe.value
            END AS VALUE,
            itemid ITEMID -- Added to the original query
        FROM
            `physionet-data.mimiciv_icu.outputevents` oe
        WHERE
            itemid IN (
                226559, -- Foley
                226560, -- Void
                226561, -- Condom Cath
                226584, -- Ileoconduit
                226563, -- Suprapubic
                226564, -- R Nephrostomy
                226565, -- L Nephrostomy
                226567, -- Straight Cath
                226557, -- R Ureteral Stent
                226558, -- L Ureteral Stent
                227488, -- GU Irrigant Volume In
                227489 -- GU Irrigant/Urine Volume Out
            )
            AND oe.stay_id IS NOT NULL
    ),
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
            uo a
            LEFT JOIN `physionet-data.mimiciv_hosp.services` c ON c.hadm_id = a.HADM_ID
            AND c.transfertime < DATETIME_ADD(a.CHARTTIME, INTERVAL 1 HOUR)
        GROUP BY
            a.STAY_ID
    )
SELECT
    uo.*,
    l.LABEL,
    s.SERVICE
FROM
    uo
    LEFT JOIN `physionet-data.mimiciv_icu.d_items` l ON l.itemid = uo.itemid
    LEFT JOIN stays_services s ON s.stay_id = uo.stay_id