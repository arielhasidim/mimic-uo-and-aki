CREATE OR REPLACE TABLE `mimic_uo_and_aki.e_aki_analysis` AS
-- Defining start and end time for oliguric-AKI events by KDIGO-UO staging criteria.
-- Oliguric-AKIs less than 3 hours apart are bridged.

WITH preceding_staging_uo AS (
        -- Joins every hourly KDIGO-UO staging with its preceding stage in the same hospital admission
        SELECT
            a.stay_id,
            a.hadm_id,
            a.charttime,
            a.aki_stage_uo,
            -- Preceding KDIGO-UO staging in hospital admission:
            ARRAY_AGG(
                b.aki_stage_uo
                ORDER BY
                    b.charttime DESC
                LIMIT
                    1
            ) [OFFSET(0)] preceding_uo_stage,
            -- Number of hours from preceding_uo_stage:
            DATETIME_DIFF(a.charttime, MAX(b.charttime), HOUR) time_from_last_stage,
        FROM
            `mimic_uo_and_aki.d3_kdigo_stages` a
            LEFT JOIN `mimic_uo_and_aki.d3_kdigo_stages` b ON b.hadm_id = a.hadm_id
            AND b.charttime < a.charttime
            AND b.aki_stage_uo IS NOT NULL
        WHERE
            a.aki_stage_uo IS NOT NULL
        GROUP BY
            a.stay_id,
            a.hadm_id,
            a.charttime,
            a.aki_stage_uo
    ),
    following_staging_uo AS (
        -- Adds to every hourly KDIGO-UO staging at the "preceding_staging_uo" CTE  with its 
        -- following stage in the same hospital admission
        SELECT
            a.stay_id,
            a.hadm_id,
            a.charttime,
            a.aki_stage_uo,
            a.preceding_uo_stage,
            a.time_from_last_stage,
            -- Next KDIGO-UO staging in hospital admission:
            ARRAY_AGG(
                c.aki_stage_uo
                ORDER BY
                    c.charttime ASC
                LIMIT
                    1
            ) [OFFSET(0)] following_uo_stage,
            -- Number of hours to following_uo_stage:
            DATETIME_DIFF(MIN(c.charttime), a.charttime, HOUR) time_to_next_stage
        FROM
            preceding_staging_uo a
            LEFT JOIN `mimic_uo_and_aki.d3_kdigo_stages` c ON c.hadm_id = a.hadm_id
            AND c.charttime > a.charttime
            AND c.aki_stage_uo IS NOT NULL
        GROUP BY
            a.stay_id,
            a.hadm_id,
            a.charttime,
            a.aki_stage_uo,
            a.preceding_uo_stage,
            a.time_from_last_stage
    ),
    discrete_oliguric_akis AS (
        -- Define discrete oliguric-AKI events according to KDIGO-UO criteria
        -- by detecting the onset and resolution of AKI events as follows:
        --         1. Start times are defined for every positive UO staging if one of the following 
        --            conditions are fulfilled:
        --              a. The preceding KDIGO-UO staging is 0.
        --              b. The is no preceding staging (the preceding stage is “NULL”).
        --              c. The duration between the current and preceding stages is above 5 hours.
        --         2. If the conditions c or b above are fulfilled, the "no_start" flag is used to 
        --            indicate that we are not sure when this event actually started (“no_start = 1”).
        --         3. End times are defined in a similar fashion for the following stage instead of the 
        --            preceding one. We added 1 hour to the KDIGO stage chart time to account for the 
        --            end of the hourly stage interval.
        --         4. “no_end” is also defined in a similar fashion to indicate that we are not sure 
        --            when this event where actually resolved.
        SELECT
            ROW_NUMBER() OVER (
                ORDER BY
                    starts.hadm_id,
                    starts.charttime
            ) AS temp_id, -- Temporary unique ID
            starts.stay_id,
            starts.hadm_id,
            starts.charttime aki_uo_starts,
            CASE
                WHEN starts.preceding_uo_stage IS NULL THEN 1
                WHEN starts.time_from_last_stage >= 6 THEN 1
                ELSE 0
            END AS no_start,
            DATETIME_ADD(MIN(ends.charttime), INTERVAL 1 HOUR) aki_uo_ends,
            CASE
                WHEN ARRAY_AGG(
                    ends.following_uo_stage
                    ORDER BY
                        ends.charttime ASC
                    LIMIT
                        1
                ) [OFFSET(0)] IS NULL THEN 1
                WHEN ARRAY_AGG(
                    ends.time_from_last_stage
                    ORDER BY
                        ends.charttime ASC
                    LIMIT
                        1
                ) [OFFSET(0)] >= 6 THEN 1
                ELSE 0
            END AS no_end,
        FROM
        -- Detecting all oliguric-AKI onset times
            (
                SELECT
                    *
                FROM
                    following_staging_uo
                WHERE
                    aki_stage_uo > 0
                    AND (
                        preceding_uo_stage = 0
                        OR preceding_uo_stage IS NULL
                        OR time_from_last_stage >= 6
                    )
            ) AS starts
            LEFT JOIN (
            -- Detecting all oliguric-AKI resolution times
                SELECT
                    *
                FROM
                    following_staging_uo
                WHERE
                    aki_stage_uo IS NOT NULL
                    AND (
                        following_uo_stage = 0
                        OR following_uo_stage IS NULL
                        OR time_to_next_stage >= 6
                    ) 
            ) AS ends ON ends.hadm_id = starts.hadm_id
            AND ends.charttime >= starts.charttime
        GROUP BY
            starts.stay_id,
            starts.hadm_id,
            starts.charttime,
            starts.preceding_uo_stage,
            starts.time_from_last_stage
    ),
    adjacent_uo_akis AS (
        -- Indicating when discrte AKI events are less than 3 hours apart (before and after).
        SELECT
            a.temp_id,
            a.stay_id,
            a.hadm_id,
            IF(b.temp_id IS NULL, 0, 1) AS just_before,
            a.aki_uo_starts,
            a.no_start,
            IF(c.temp_id IS NULL, 0, 1) AS just_after,
            a.aki_uo_ends,
            a.no_end
        FROM
            discrete_oliguric_akis a
            LEFT JOIN discrete_oliguric_akis b ON b.hadm_id = a.hadm_id
            AND b.aki_uo_starts < a.aki_uo_starts
            AND b.aki_uo_ends > DATE_ADD(a.aki_uo_starts, INTERVAL -3 HOUR)
            LEFT JOIN discrete_oliguric_akis c ON c.hadm_id = a.hadm_id
            AND c.aki_uo_starts > a.aki_uo_starts
            AND c.aki_uo_starts < DATE_ADD(a.aki_uo_ends, INTERVAL 3 HOUR)
    ),
    bridged_uo_akis AS (
        -- Bridging adjacent events.
        SELECT
            temp_id,
            stay_id,
            hadm_id,
            aki_uo_starts,
            no_start,
            aki_uo_ends,
            no_end
        FROM
            adjacent_uo_akis
        WHERE
            just_before = 0
            AND just_after = 0
        UNION ALL
        SELECT
            a.temp_id,
            a.stay_id,
            a.hadm_id,
            a.aki_uo_starts,
            a.no_start,
            MIN(b.aki_uo_ends) aki_uo_ends,
            ARRAY_AGG(
                b.no_end
                ORDER BY
                    b.aki_uo_ends ASC
                LIMIT
                    1
            ) [OFFSET(0)] no_end
        FROM
            adjacent_uo_akis a
            LEFT JOIN adjacent_uo_akis b ON b.hadm_id = a.hadm_id
            AND b.aki_uo_starts > a.aki_uo_starts
            AND b.just_before = 1
            AND b.just_after = 0
        WHERE
            a.just_before = 0
            AND a.just_after = 1
        GROUP BY
            a.temp_id,
            a.stay_id,
            a.hadm_id,
            a.aki_uo_starts,
            a.no_start
    ),
    worst_staging AS (
        -- Detecting worst KDIGO-UO staging per oliguric-AKI event.
        SELECT
            a.temp_id,
            MAX(b.aki_stage_uo) WORST_STAGE
        FROM
            bridged_uo_akis a
            LEFT JOIN `mimic_uo_and_aki.d3_kdigo_stages` b ON b.hadm_id = a.hadm_id
            AND b.charttime >= a.aki_uo_starts
            AND b.charttime < a.aki_uo_ends
        GROUP BY
            a.temp_id
    )

SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            b.SUBJECT_ID,
            a.aki_uo_starts
    ) AS AKI_ID,
    b.SUBJECT_ID,
    b.HADM_ID,
    a.STAY_ID,
    c.WEIGHT,
    a.aki_uo_starts AS AKI_START,
    a.aki_uo_ends AS AKI_STOP,
    a.no_start AS NO_START,
    a.no_end AS NO_END,
    d.WORST_STAGE
FROM
    bridged_uo_akis a
    LEFT JOIN `physionet-data.mimiciv_icu.icustays` b ON a.stay_id = b.stay_id
    LEFT JOIN `physionet-data.mimiciv_derived.first_day_weight` c ON c.stay_id = a.stay_id
    LEFT JOIN worst_staging d ON d.temp_id = a.temp_id
ORDER BY
    b.SUBJECT_ID,
    a.aki_uo_starts
