CREATE OR REPLACE TABLE `mimic_uo_and_aki.e_aki_analysis` AS
-- Defining start and end time for aki events by KDIGO staging,
-- and bridging uo-akis with less then 3 hours gap.

WITH
    -- Joins every following uo-kdigo staging per icu stay for detecting start and end of event later
    sequential_staging_uo_before AS (
        SELECT
            a.stay_id,
            a.charttime,
            a.aki_stage_uo,
            ARRAY_AGG(
                b.aki_stage_uo
                ORDER BY
                    b.charttime DESC
                LIMIT
                    1
            ) [OFFSET(0)] prev_uo_stage, -- Previous uo-staging in ICU stay ever
            MAX(b.charttime) prev_uo_stage_charttime,
            DATETIME_DIFF(a.charttime, MAX(b.charttime), HOUR) time_from_last_stage -- Number of hours from prev_uo_stage
        FROM
            `mimic_uo_and_aki.d3_kdigo_stages` a
            LEFT JOIN `mimic_uo_and_aki.d3_kdigo_stages` b ON b.stay_id = a.stay_id
            AND b.charttime < a.charttime
            AND b.aki_stage_uo IS NOT NULL
        WHERE
            a.aki_stage_uo IS NOT NULL
        GROUP BY
            a.stay_id,
            a.charttime,
            a.aki_stage_uo
    ),
    -- Joins positive kdigo-uo staging in the 3 hours before and after for bridging adjacent AKIS
    bridging_staging_uo AS (
        SELECT
            a.stay_id,
            a.charttime,
            a.aki_stage_uo,
            a.prev_uo_stage,
            a.prev_uo_stage_charttime,
            a.time_from_last_stage,
            ARRAY_AGG( -- Array for bridging UO-AKI events less than 3 hour before
                -- Positive kdigo-uo staging in the 3 hours before:
                IF(b.charttime < a.charttime, b.aki_stage_uo, NULL) IGNORE NULLS
            ) AS consecutive_aki_before,
            ARRAY_AGG( -- Array for bridging UO-AKI events less than 3 hour after
                -- Positive kdigo-uo staging in the 3 hours after:
                IF(b.charttime > a.charttime, b.aki_stage_uo, NULL) IGNORE NULLS
            ) AS consecutive_aki_after,
        FROM
            sequential_staging_uo_before a
            LEFT JOIN `mimic_uo_and_aki.d3_kdigo_stages` b ON b.stay_id = a.stay_id
            AND b.charttime < DATETIME_ADD(a.charttime, INTERVAL 3 HOUR)
            AND b.charttime >= DATETIME_ADD(a.charttime, INTERVAL -3 HOUR)
            AND b.aki_stage_uo > 0
        GROUP BY
            a.stay_id,
            a.charttime,
            a.aki_stage_uo,
            a.prev_uo_stage,
            a.prev_uo_stage_charttime,
            a.time_from_last_stage
    ),
    -- Defining start and stop time for AKI events according to KDIGO UO criteria as follows:
    --      1. Start time is defines for every positive UO staging when:
    --          a. The last UO staging in ICU ever is 0 or NULL
    --          b. The array of "positive kdigo-uo staging in the 3 hours before" is empty
    --      2. When the is no recored of previuos UO-AKI staging ever (NULL), then "no_start" 
    --         flag is equal 1 to indicate that we are not sure when this event started.
    --      3. End time with "no_end" flag is equal to 0 when:
    --          a. We have a charttime with ou-stage=0, and it's equal to "next_uo_stage_0_charttime"
    --          b. The mentioned charttime above was taken less then 6 hours after a record 
    --             of a positive staging
    --          c. The array of "positive kdigo-uo staging in the 3 hours before" for the 
    --             mentioned charttime is empty (NULL)
    --      4. Else, "no_end" flag is equal to 1, and end time is defined in the following order of existence:
    --          a. If the next uo-stage=0 is >=6 hours after the last posetive staging, 
    --             we will use the end of the last positive stage
    --          b. If no next uo-stage=0, we use ICU stay out time from "physionet-data.mimiciv_icu.icustays" table
    aki_uo AS (
        SELECT
            a.stay_id,
            a.charttime aki_uo_starts,
            CASE
                WHEN a.prev_uo_stage IS NULL THEN 1
                ELSE 0
            END AS no_start, -- No previous uo-staging in ICU stay, means AKI started before ICU addmission
            IFNULL(
                MIN(
                    IF(
                        b.aki_stage_uo = 0
                        AND ARRAY_LENGTH(b.consecutive_aki_after) IS NULL, -- Earliest stage 0 after AKI started with no need for bridging
                        IF( -- If stage=0 time has been taken 6 hours or later from last positive AKI staging: 
                            --     take last positive staging charttime, else take stage=0 charttime
                            b.time_from_last_stage < 6,
                            b.charttime,
                            DATETIME_ADD(b.prev_uo_stage_charttime, INTERVAL 1 HOUR)
                        ),
                        NULL
                    )
                ),
                IFNULL(
                    DATETIME_ADD(MAX(b.charttime), INTERVAL 1 HOUR),
                    IF(
                        c.outtime > a.charttime,
                        c.outtime,
                        DATETIME_ADD(a.charttime, INTERVAL 1 HOUR)
                    )
                ) -- Fallbacks: i. charttime of the last positive staging; ii. ICU out-time
            ) AS aki_uo_ends,
            IF(
                MIN(
                    IF(
                        b.aki_stage_uo = 0
                        AND ARRAY_LENGTH(b.consecutive_aki_after) IS NULL,
                        IF(b.time_from_last_stage < 6, b.charttime, NULL),
                        NULL
                    )
                ) IS NULL,
                1,
                0
            ) AS no_end -- Means that "aki_uo_ends" value is showing the last positive 
            --             staging charttime, if doesnt exist using outtime???
        FROM
            bridging_staging_uo a
            LEFT JOIN bridging_staging_uo b ON b.stay_id = a.stay_id
            AND b.charttime > a.charttime
            AND b.aki_stage_uo IS NOT NULL
            LEFT JOIN `physionet-data.mimiciv_icu.icustays` c ON c.stay_id = a.stay_id
        WHERE
            a.aki_stage_uo > 0
            AND (
                a.prev_uo_stage = 0
                OR a.prev_uo_stage IS NULL
            ) -- Detecting all aki-uo start times
            AND ARRAY_LENGTH(a.consecutive_aki_before) IS NULL
            -- ^ Bridging UO-AKI that ended less then 3 hours before current AKI begins
        GROUP BY
            a.stay_id,
            a.charttime,
            a.prev_uo_stage,
            --     a.next_uo_stage_0_charttime, REMOVE??
            c.outtime
    ),
    -- Joins every following creat-kdigo staging per icu stay for detecting start and end of event later
    sequential_staging_creat_before AS (
        SELECT
            a.stay_id,
            a.charttime,
            a.aki_stage_creat,
            ARRAY_AGG(
                b.aki_stage_creat
                ORDER BY
                    b.charttime DESC
                LIMIT
                    1
            ) [OFFSET(0)] prev_creat_stage, -- Previous creat-staging in ICU stay ever
        FROM
            `mimic_uo_and_aki.d3_kdigo_stages` a
            LEFT JOIN `mimic_uo_and_aki.d3_kdigo_stages` b ON b.stay_id = a.stay_id
            AND b.charttime < a.charttime
            AND b.aki_stage_creat IS NOT NULL
        WHERE
            a.aki_stage_creat IS NOT NULL
        GROUP BY
            a.stay_id,
            a.charttime,
            a.aki_stage_creat
    ),
    -- Defining start and stop time for AKI events according to KDIGO creatinine criteria as follows:
    --      1. Start time is defines for every positive creat-staging when:
    --          a. The last creatinine staging in ICU ever is 0 or NULL
    --      2. When the is no recored of previuos CREAT-AKI staging ever (NULL), then "no_start" 
    --         flag is equal 1 to indicate that we are not sure when this event started.
    --      3. End time with "no_end" flag is equal to 0 when:
    --          a. We have a charttime with creat-stage=0, and it's equal to "next_creat_stage_0_charttime"
    --      4. Else, "no_end" flag is equal to 1, and end time is defined in the following order of existence:
    --          a. The last positive creat-staging known after aki event started
    --          b. ICU stay out time from "physionet-data.mimiciv_icu.icustays" table
    aki_creat AS (
        SELECT
            a.stay_id,
            a.charttime aki_creat_starts,
            a.aki_stage_creat,
            CASE
                WHEN a.prev_creat_stage IS NULL THEN 1
                ELSE 0
            END AS no_start, -- No previous creat-staging in ICU stay
            IFNULL(
                MIN(IF(b.aki_stage_creat = 0, b.charttime, NULL)),
                IFNULL(MAX(b.charttime), c.outtime)
            ) AS aki_creat_ends,
            IF(
                MIN(IF(b.aki_stage_creat = 0, b.charttime, NULL)) IS NOT NULL,
                0,
                1
            ) AS no_end -- Means that "aki_creat_ends" value is showing the last positive 
            --             staging charttime, if doesnt exist using outtime???
        FROM
            sequential_staging_creat_before a
            LEFT JOIN sequential_staging_creat_before b ON b.stay_id = a.stay_id
            AND b.charttime > a.charttime
            AND b.aki_stage_creat IS NOT NULL
            LEFT JOIN `physionet-data.mimiciv_icu.icustays` c ON c.stay_id = a.stay_id
        WHERE
            a.aki_stage_creat > 0
            AND (
                a.prev_creat_stage = 0
                OR a.prev_creat_stage IS NULL
            ) -- Detecting all aki-uo start times
        GROUP BY
            a.stay_id,
            a.charttime,
            a.aki_stage_creat,
            a.prev_creat_stage,
            c.outtime
    ),
    -- Joining in both types of AKI, with type 1 for UO, and type 2 for creatining.
    -- Adding valid hourly adjusted uo rate
    aki_events AS (
        SELECT
            b.SUBJECT_ID,
            b.HADM_ID,
            a.STAY_ID,
            IFNULL(c.WEIGHT_ADMIT, c.WEIGHT) WEIGHT,
            a.AKI_START,
            a.AKI_STOP,
            a.AKI_TYPE,
            a.NO_START,
            a.NO_END
        FROM
            (
                SELECT
                    stay_id,
                    aki_uo_starts aki_start,
                    aki_uo_ends aki_stop,
                    no_start,
                    no_end,
                    1 aki_type
                FROM
                    aki_uo
                UNION ALL
                SELECT
                    stay_id,
                    aki_creat_starts aki_start,
                    aki_creat_ends aki_stop,
                    no_start,
                    no_end,
                    2 aki_type
                FROM
                    aki_creat
            ) a
            LEFT JOIN `physionet-data.mimiciv_icu.icustays` b ON a.STAY_ID = b.STAY_ID
            LEFT JOIN `physionet-data.mimiciv_derived.first_day_weight` c ON c.STAY_ID = a.STAY_ID
    ),
    -- Summing up worst staging per event according to event type
    with_aki_id AS (
        SELECT
            ROW_NUMBER() OVER (
                ORDER BY
                    SUBJECT_ID,
                    AKI_START
            ) AS AKI_ID,
            a.*
        FROM
            aki_events a
    ),
    worst_staging AS (
        SELECT
            a.AKI_ID,
            MAX(
                CASE
                    WHEN a.aki_type = 1 THEN b.aki_stage_uo
                    WHEN a.aki_type = 2 THEN b.aki_stage_creat
                    ELSE NULL
                END
            ) WORST_STAGE
        FROM
            with_aki_id a
            LEFT JOIN `mimic_uo_and_aki.d3_kdigo_stages` b ON b.stay_id = a.stay_id
            AND b.charttime >= a.aki_start
            AND b.charttime < a.aki_stop
        GROUP BY
            a.AKI_ID
    )

SELECT
    a.*,
    b.WORST_STAGE
FROM
    with_aki_id a
    LEFT JOIN worst_staging b ON b.aki_id = a.aki_id