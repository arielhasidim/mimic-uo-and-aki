CREATE OR REPLACE TABLE `mimic_uo_and_aki.c_hourly_uo_99all_temp` AS

WITH
  -- Array of numbers that represent total hours measured for specific STAY_ID 
  -- + start-time rounded down + end-time rounded up
  RAW_ARRAY_OF_TIMES AS (
    SELECT
      STAY_ID,
      GENERATE_ARRAY(
        1,
        -- hours diffrence between:
        DATETIME_DIFF(
          -- last spot uo chart-time rounded up
          DATETIME_TRUNC(
            DATETIME_ADD(MAX(uo.charttime), INTERVAL 3599 SECOND),
            HOUR
          ),
          -- first spot uo chart-time rounded down
          DATETIME_TRUNC(MIN(uo.charttime), HOUR),
          HOUR
        ),
        1
      ) ary,
      -- stating start time rounded down
      DATETIME_TRUNC(MIN(uo.charttime), HOUR) start_time_rounded_down,
      -- stating end time rounded up
      DATETIME_TRUNC(
        DATETIME_ADD(MAX(uo.charttime), INTERVAL 3599 SECOND),
        HOUR
      ) end_time_rounded_up,
      DATETIME_DIFF(
        DATETIME_TRUNC(
          DATETIME_ADD(MAX(uo.charttime), INTERVAL 3599 SECOND),
          HOUR
        ),
        DATETIME_TRUNC(MIN(uo.charttime), HOUR),
        HOUR
      ) TIME_DIFF -- for testing reasons
    FROM
      `mimic_uo_and_aki.b_uo_rate_temp` uo
    GROUP BY
      STAY_ID
  ),
  LISTED_ARRAY_OF_TIMES AS (
    SELECT
      *
    FROM
      RAW_ARRAY_OF_TIMES
      CROSS JOIN UNNEST (ary) AS T_PLUS
  ),
  -- total hours list + absolute time intervals
  TIMES_WITH_INTERVALS AS (
    SELECT
      laot.STAY_ID,
      laot.T_PLUS,
      laot.START_TIME_ROUNDED_DOWN,
      DATETIME_ADD(START_TIME_ROUNDED_DOWN, INTERVAL T_PLUS - 1 HOUR) AS TIME_INTERVAL_STARTS,
      DATETIME_ADD(START_TIME_ROUNDED_DOWN, INTERVAL T_PLUS HOUR) AS TIME_INTERVAL_FINISH,
    FROM
      LISTED_ARRAY_OF_TIMES laot
    GROUP BY
      laot.T_PLUS,
      laot.STAY_ID,
      laot.START_TIME_ROUNDED_DOWN,
      TIME_INTERVAL_STARTS,
      TIME_INTERVAL_FINISH
  ),
  -- all hours of measurements in icu stay, with rates per each hour and its proportion and validity
  INTERVALS_WITH_RATES AS (
    SELECT
      a.STAY_ID,
      a.T_PLUS,
      a.START_TIME_ROUNDED_DOWN,
      a.TIME_INTERVAL_STARTS,
      a.TIME_INTERVAL_FINISH,
      b.HOURLY_RATE,
      b.CHARTTIME,
      b.LAST_CHARTTIME,
      DATETIME_DIFF(
        LEAST(b.CHARTTIME, a.TIME_INTERVAL_FINISH),
        GREATEST(b.LAST_CHARTTIME, a.TIME_INTERVAL_STARTS),
        MINUTE
      ) / 60 PROPORTION,
      b.SOURCE
    FROM
      TIMES_WITH_INTERVALS a
      LEFT JOIN `mimic_uo_and_aki.b_uo_rate_temp` b ON b.STAY_ID = a.STAY_ID
      AND b.CHARTTIME > a.TIME_INTERVAL_STARTS
      AND b.LAST_CHARTTIME < a.TIME_INTERVAL_FINISH
      --  for sensetivity analysis:
      AND b.TIME_INTERVAL < b.percentile99_all
  ),
  -- summing up rated per each hour by its proportion only if valid
  CALCULATION AS (
    SELECT
      STAY_ID,
      T_PLUS,
      TIME_INTERVAL_STARTS,
      TIME_INTERVAL_FINISH,
      SUM(HOURLY_RATE * PROPORTION) / (
        DATETIME_DIFF(
          LEAST(TIME_INTERVAL_FINISH, MAX(CHARTTIME)),
          GREATEST(TIME_INTERVAL_STARTS, MIN(LAST_CHARTTIME)),
          MINUTE
        ) / 60
      ) AS HOURLY_VALID_WEIGHTED_MEAN_RATE,
      GREATEST(TIME_INTERVAL_STARTS, MIN(LAST_CHARTTIME)) COVERED_START,
      LEAST(TIME_INTERVAL_FINISH, MAX(CHARTTIME)) COVERED_END,
      DATETIME_DIFF(
        LEAST(TIME_INTERVAL_FINISH, MAX(CHARTTIME)),
        GREATEST(TIME_INTERVAL_STARTS, MIN(LAST_CHARTTIME)),
        MINUTE
      ) / 60 AS PROPORTION_COVERED
    FROM
      INTERVALS_WITH_RATES
    GROUP BY
      STAY_ID,
      T_PLUS,
      TIME_INTERVAL_STARTS,
      TIME_INTERVAL_FINISH
  )
  -- final table. 
  -- HOURLY_VALID_WEIGHTED_MEAN_RATE is presented only when we have UO rate for most of the hour
  -- also showing next to each hour simple uo value sum for comparison
SELECT
  a.STAY_ID,
  a.T_PLUS,
  a.TIME_INTERVAL_STARTS,
  a.TIME_INTERVAL_FINISH,
  IF(
    a.PROPORTION_COVERED > 0.5,
    a.HOURLY_VALID_WEIGHTED_MEAN_RATE,
    NULL
  ) HOURLY_VALID_WEIGHTED_MEAN_RATE,
  IFNULL(SUM(b.VALUE), 0) SIMPLE_SUM,
  IFNULL(c.WEIGHT_ADMIT, c.WEIGHT) WEIGHT_ADMIT
FROM
  CALCULATION a
  LEFT JOIN `mimic_uo_and_aki.a_urine_output_raw` b ON b.STAY_ID = a.STAY_ID
  AND b.CHARTTIME > a.TIME_INTERVAL_STARTS
  AND b.CHARTTIME <= a.TIME_INTERVAL_FINISH
  LEFT JOIN `physionet-data.mimiciv_derived.first_day_weight` c ON c.STAY_ID = a.STAY_ID
GROUP BY
  a.STAY_ID,
  a.T_PLUS,
  a.TIME_INTERVAL_STARTS,
  a.TIME_INTERVAL_FINISH,
  a.PROPORTION_COVERED,
  a.HOURLY_VALID_WEIGHTED_MEAN_RATE,
  c.WEIGHT_ADMIT,
  c.WEIGHT