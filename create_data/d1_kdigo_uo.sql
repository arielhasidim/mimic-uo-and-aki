CREATE OR REPLACE TABLE `mimic_uo_and_aki.d1_kdigo_uo` AS

-- we used mimic_code's KDIGO staging with adaption for hourly urine output rate
-- link (10/10/2022): https://github.com/MIT-LCP/mimic-code/tree/main/mimic-iv/concepts/organfailure
WITH
  ur_stg AS (
    SELECT
      io.stay_id,
      io.TIME_INTERVAL_FINISH, -- Will end up as charttime at the end
      SUM(
        CASE
          WHEN iosum.TIME_INTERVAL_FINISH >= DATETIME_SUB(io.TIME_INTERVAL_FINISH, INTERVAL '5' HOUR) THEN iosum.HOURLY_VALID_WEIGHTED_MEAN_RATE
          ELSE NULL
        END
      ) AS urineoutput_6hr, -- Summing UO for 6 hours
      SUM(
        CASE
          WHEN iosum.TIME_INTERVAL_FINISH >= DATETIME_SUB(io.TIME_INTERVAL_FINISH, INTERVAL '11' HOUR) THEN iosum.HOURLY_VALID_WEIGHTED_MEAN_RATE
          ELSE NULL
        END
      ) AS urineoutput_12hr, -- Summing UO for 12 hours
      SUM(iosum.HOURLY_VALID_WEIGHTED_MEAN_RATE) AS urineoutput_24hr, -- Summing UO for 24 hours
     
     -- Extracts the number of hours over which we've tabulated UO in 6 hours window,
      -- will be used to calculate rate in the next stage below
      ROUND(
        CAST(
          DATETIME_DIFF(
            io.TIME_INTERVAL_FINISH,
            MIN( -- Gets the earliest time that was used in the summation of 6 hours window
              CASE
                WHEN iosum.TIME_INTERVAL_FINISH >= DATETIME_SUB(io.TIME_INTERVAL_FINISH, INTERVAL '5' HOUR) THEN iosum.TIME_INTERVAL_FINISH
                ELSE NULL
              END
            ),
            SECOND
          ) AS NUMERIC
        ) / 3600.0,
        4
      ) AS uo_tm_6hr,
      -- Repeat extraction for 12 hours and 24 hours
      ROUND(
        CAST(
          DATETIME_DIFF(
            io.TIME_INTERVAL_FINISH,
            MIN( -- Gets the earliest time that was used in the summation of 12 hours window
              CASE
                WHEN iosum.TIME_INTERVAL_FINISH >= DATETIME_SUB(io.TIME_INTERVAL_FINISH, INTERVAL '11' HOUR) THEN iosum.TIME_INTERVAL_FINISH
                ELSE NULL
              END
            ),
            SECOND
          ) AS NUMERIC
        ) / 3600.0,
        4
      ) AS uo_tm_12hr,
      ROUND(
        CAST(
          DATETIME_DIFF(
            io.TIME_INTERVAL_FINISH,
            MIN(iosum.TIME_INTERVAL_FINISH),  -- Gets the earliest time that was used in the summation of 24 hours window
            SECOND
          ) AS NUMERIC
        ) / 3600.0,
        4
      ) AS uo_tm_24hr,
      COUNT(
              CASE
                WHEN iosum.TIME_INTERVAL_FINISH >= DATETIME_SUB(io.TIME_INTERVAL_FINISH, INTERVAL '5' HOUR) THEN iosum.TIME_INTERVAL_FINISH
                ELSE NULL
              END
            ) uo_count_6hr,
      COUNT(
              CASE
                WHEN iosum.TIME_INTERVAL_FINISH >= DATETIME_SUB(io.TIME_INTERVAL_FINISH, INTERVAL '11' HOUR) THEN iosum.TIME_INTERVAL_FINISH
                ELSE NULL
              END
            ) uo_count_12hr,
      COUNT(iosum.TIME_INTERVAL_FINISH) uo_count_24hr,
      io.WEIGHT_ADMIT weight_first
    FROM
      `mimic_uo_and_aki.c_hourly_uo` io
      -- this join gives all UO measurements over the 24 hours preceding this row
      LEFT JOIN `mimic_uo_and_aki.c_hourly_uo` iosum ON io.stay_id = iosum.stay_id
      AND iosum.TIME_INTERVAL_FINISH <= io.TIME_INTERVAL_FINISH
      AND iosum.TIME_INTERVAL_FINISH >= DATETIME_SUB(io.TIME_INTERVAL_FINISH, INTERVAL '23' HOUR)
      AND iosum.HOURLY_VALID_WEIGHTED_MEAN_RATE IS NOT NULL
    WHERE
      io.HOURLY_VALID_WEIGHTED_MEAN_RATE IS NOT NULL
    GROUP BY
      io.stay_id,
      io.TIME_INTERVAL_FINISH,
      io.WEIGHT_ADMIT
  )
SELECT
  ur.stay_id,
  ur.TIME_INTERVAL_FINISH AS charttime,
  ur.weight_first,
  ur.urineoutput_6hr,
  ur.urineoutput_12hr,
  ur.urineoutput_24hr,
  -- calculate rates - adding 1 hour as we assume data charted at 10:00 corresponds to previous hour
  ROUND(
    CAST(
      (
        ur.urineoutput_6hr / ur.weight_first / (uo_tm_6hr + 1)
      ) AS NUMERIC
    ),
    4
  ) AS uo_rt_6hr,
  ROUND(
    CAST(
      (
        ur.urineoutput_12hr / ur.weight_first / (uo_tm_12hr + 1)
      ) AS NUMERIC
    ),
    4
  ) AS uo_rt_12hr,
  ROUND(
    CAST(
      (
        ur.urineoutput_24hr / ur.weight_first / (uo_tm_24hr + 1)
      ) AS NUMERIC
    ),
    4
  ) AS uo_rt_24hr,
  uo_tm_6hr, -- only for tesing, no actual use in next queries.
  uo_tm_12hr, -- only for tesing, no actual use in next queries.
  uo_tm_24hr, -- only for tesing, no actual use in next queries.

  -- Number of recoreded hours of UO between current UO time and earliest 
  -- charted UO within the X hour window. Used for validation in next queries.
  uo_count_6hr,
  uo_count_12hr,
  uo_count_24hr,
FROM
  ur_stg ur;