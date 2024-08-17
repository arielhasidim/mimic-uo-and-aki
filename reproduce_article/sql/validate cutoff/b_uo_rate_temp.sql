CREATE OR REPLACE TABLE `mimic_uo_and_aki.b_uo_rate_temp` AS

WITH uo_with_intervals_sources_and_weight AS (
        -- Raw UO with its source and charttime, preceding charttime in the 
        -- same compartment, and calculated time interval
        SELECT
            a.HADM_ID,
            a.STAY_ID,
            a.VALUE,
            a.CHARTTIME,
            a.ITEMID,
            a.SERVICE,
            c.LABEL,
            MAX(b.CHARTTIME) AS LAST_CHARTTIME,
            (
                DATETIME_DIFF(a.CHARTTIME, MAX(b.CHARTTIME), SECOND) / 60
            ) AS TIME_INTERVAL,
            IFNULL(w.WEIGHT_ADMIT, w.WEIGHT) WEIGHT_ADMIT
        FROM
            `mimic_uo_and_aki.a_urine_output_raw` a
            LEFT JOIN `mimic_uo_and_aki.a_urine_output_raw` b ON b.STAY_ID = a.STAY_ID
            AND b.CHARTTIME < a.CHARTTIME
            -- The rates for right and left nephrostomy and ileoconduit will be calculated from 
            -- the last identical item as each of them represents a different compartment 
            -- other than the urinary bladder.
            AND IF(
                a.ITEMID IN (226565, 226564, 226584),
                b.ITEMID = a.ITEMID,
                b.ITEMID NOT IN (226565, 226564, 226584)
            )
            LEFT JOIN `physionet-data.mimiciv_icu.d_items` c ON c.itemid = a.itemid
            LEFT JOIN `physionet-data.mimiciv_derived.first_day_weight` w ON w.STAY_ID = a.STAY_ID
        GROUP BY
            a.HADM_ID,
            a.STAY_ID,
            a.VALUE,
            a.CHARTTIME,
            a.ITEMID,
            c.LABEL,
            w.WEIGHT_ADMIT,
            w.WEIGHT,
            a.SERVICE
    ),
    excluding AS (
        -- excluding unreliable ICU stays
        SELECT
            HADM_ID,
            STAY_ID,
            label AS SOURCE,
            VALUE,
            CHARTTIME,
            LAST_CHARTTIME,
            TIME_INTERVAL,
            WEIGHT_ADMIT,
            SERVICE
        FROM
            uo_with_intervals_sources_and_weight
        WHERE
            -- Exclude all stays with ureteral stent or GU irrigation 
            -- (See https://github.com/MIT-LCP/mimic-code/issues/745 for GU irrig.)
            STAY_ID NOT IN (
                SELECT
                    STAY_ID
                FROM
                    `physionet-data.mimiciv_icu.outputevents`
                WHERE
                    ITEMID IN (227488, 227489, 226558, 226557)
                GROUP BY
                    STAY_ID
            )
            -- Sanity check
            AND VALUE >= 0
            AND VALUE < 5000
            -- ICU stay type inclusion by service
            AND SERVICE IN (
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
    ),
    interval_precentiles_approx AS (
        -- Calculating 95th precentile for all and for less than 20ml urine output recoreds by source type
        SELECT
            SOURCE,
            APPROX_QUANTILES(TIME_INTERVAL, 100) [OFFSET(95)] AS percentile95_all,
            APPROX_QUANTILES(TIME_INTERVAL, 100) [OFFSET(99)] AS percentile99_all,
            APPROX_QUANTILES(
                (
                    CASE
                        WHEN (VALUE / (TIME_INTERVAL / 60)) <= 20 THEN TIME_INTERVAL
                    END
                ),
                100
            ) [OFFSET(95)] AS percentile95_20,
            APPROX_QUANTILES(
                (
                    CASE
                        WHEN (VALUE / (TIME_INTERVAL / 60)) <= 20 THEN TIME_INTERVAL
                    END
                ),
                100
            ) [OFFSET(99)] AS percentile99_20
        FROM
            (
                SELECT
                    * EXCEPT (SOURCE),
                    IF(
                        SOURCE = "R Nephrostomy"
                        OR SOURCE = "L Nephrostomy",
                        "Nephrostomy",
                        SOURCE
                    ) AS SOURCE,
                FROM
                    excluding
            )
        GROUP BY
            SOURCE
    ),
    added_validity AS (
        -- Adding durations collection prediods precentiles to evalute validity later in a sensetivity analysis Evaluate validity by setting cut-off value for maximal interval time by output source.
        SELECT
            a.*,
            -- Used for sensetivity analysis:
            b.percentile95_all,
            b.percentile99_all,
            b.percentile95_20,
            percentile99_20
        FROM
            excluding a
            LEFT JOIN interval_precentiles_approx b ON b.SOURCE = a.SOURCE
            OR (
                b.SOURCE = "Nephrostomy"
                AND a.SOURCE LIKE "%Nephrostomy"
            )
    )
    -- Hourly rate is finally calculated
SELECT
    a.*,
    VALUE / (TIME_INTERVAL / 60) AS HOURLY_RATE
FROM
    added_validity a