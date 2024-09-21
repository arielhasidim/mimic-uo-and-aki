CREATE OR REPLACE TABLE
  `mimic_uo_and_aki.d1_kdigo_uo_99all_temp` AS
WITH
  uo_6hr AS (
    SELECT
      index_hour.stay_id,
      index_hour.TIME_INTERVAL_FINISH, -- index hour
      SUM(uo.HOURLY_VALID_WEIGHTED_MEAN_RATE) / COUNT(uo.HOURLY_VALID_WEIGHTED_MEAN_RATE) AS rt_mean_6hr,
      MAX(uo.HOURLY_VALID_WEIGHTED_MEAN_RATE) AS uo_max_6hr,
      COUNT(uo.HOURLY_VALID_WEIGHTED_MEAN_RATE) AS valid_hrs
    FROM
      `mimic_uo_and_aki.c_hourly_uo_99all_temp` index_hour
      -- this join gives all UO measurements over the 6 hours preceding this row
      LEFT JOIN `mimic_uo_and_aki.c_hourly_uo_99all_temp` uo ON index_hour.stay_id = uo.stay_id
      AND uo.TIME_INTERVAL_FINISH <= index_hour.TIME_INTERVAL_FINISH
      AND uo.TIME_INTERVAL_FINISH >= DATETIME_SUB(
        index_hour.TIME_INTERVAL_FINISH,
        INTERVAL '5' HOUR
      )
      AND uo.HOURLY_VALID_WEIGHTED_MEAN_RATE IS NOT NULL
    WHERE
      index_hour.HOURLY_VALID_WEIGHTED_MEAN_RATE IS NOT NULL
    GROUP BY
      index_hour.stay_id,
      index_hour.TIME_INTERVAL_FINISH
  ),
  uo_12hr AS (
    SELECT
      index_hour.stay_id,
      index_hour.TIME_INTERVAL_FINISH, -- index hour
      SUM(uo.HOURLY_VALID_WEIGHTED_MEAN_RATE) / COUNT(uo.HOURLY_VALID_WEIGHTED_MEAN_RATE) AS rt_mean_12hr,
      MAX(uo.HOURLY_VALID_WEIGHTED_MEAN_RATE) AS uo_max_12hr,
      COUNT(uo.HOURLY_VALID_WEIGHTED_MEAN_RATE) AS valid_hrs
    FROM
      `mimic_uo_and_aki.c_hourly_uo_99all_temp` index_hour
      -- this join gives all UO measurements over the 12 hours preceding this row
      LEFT JOIN `mimic_uo_and_aki.c_hourly_uo_99all_temp` uo ON index_hour.stay_id = uo.stay_id
      AND uo.TIME_INTERVAL_FINISH <= index_hour.TIME_INTERVAL_FINISH
      AND uo.TIME_INTERVAL_FINISH >= DATETIME_SUB(
        index_hour.TIME_INTERVAL_FINISH,
        INTERVAL '11' HOUR
      )
      AND uo.HOURLY_VALID_WEIGHTED_MEAN_RATE IS NOT NULL
    WHERE
      index_hour.HOURLY_VALID_WEIGHTED_MEAN_RATE IS NOT NULL
    GROUP BY
      index_hour.stay_id,
      index_hour.TIME_INTERVAL_FINISH
  ),
  uo_24hr AS (
    SELECT
      index_hour.stay_id,
      index_hour.TIME_INTERVAL_FINISH, -- index hour
      SUM(uo.HOURLY_VALID_WEIGHTED_MEAN_RATE) / COUNT(uo.HOURLY_VALID_WEIGHTED_MEAN_RATE) AS rt_mean_24hr,
      MAX(uo.HOURLY_VALID_WEIGHTED_MEAN_RATE) AS uo_max_24hr,
      COUNT(uo.HOURLY_VALID_WEIGHTED_MEAN_RATE) AS valid_hrs
    FROM
      `mimic_uo_and_aki.c_hourly_uo_99all_temp` index_hour
      -- this join gives all UO measurements over the 24 hours preceding this row
      LEFT JOIN `mimic_uo_and_aki.c_hourly_uo_99all_temp` uo ON index_hour.stay_id = uo.stay_id
      AND uo.TIME_INTERVAL_FINISH <= index_hour.TIME_INTERVAL_FINISH
      AND uo.TIME_INTERVAL_FINISH >= DATETIME_SUB(
        index_hour.TIME_INTERVAL_FINISH,
        INTERVAL '23' HOUR
      )
      AND uo.HOURLY_VALID_WEIGHTED_MEAN_RATE IS NOT NULL
    WHERE
      index_hour.HOURLY_VALID_WEIGHTED_MEAN_RATE IS NOT NULL
    GROUP BY
      index_hour.stay_id,
      index_hour.TIME_INTERVAL_FINISH
  )
SELECT
  index_hour.stay_id,
  index_hour.TIME_INTERVAL_FINISH AS charttime,
  index_hour.WEIGHT_ADMIT AS weight_first,
  uo_6hr.rt_mean_6hr,
  uo_6hr.rt_mean_6hr / index_hour.WEIGHT_ADMIT AS uo_rt_kg_6hr,
  uo_6hr.uo_max_6hr,
  uo_6hr.uo_max_6hr / index_hour.WEIGHT_ADMIT AS uo_max_kg_6hr,
  uo_12hr.rt_mean_12hr,
  uo_12hr.rt_mean_12hr / index_hour.WEIGHT_ADMIT AS uo_rt_kg_12hr,
  uo_12hr.uo_max_12hr,
  uo_12hr.uo_max_12hr / index_hour.WEIGHT_ADMIT AS uo_max_kg_12hr,
  uo_24hr.rt_mean_24hr,
  uo_24hr.rt_mean_24hr / index_hour.WEIGHT_ADMIT AS uo_rt_kg_24hr,
  uo_24hr.uo_max_24hr,
  uo_24hr.uo_max_24hr / index_hour.WEIGHT_ADMIT AS uo_max_kg_24hr,
FROM
  `mimic_uo_and_aki.c_hourly_uo_99all_temp` AS index_hour
  LEFT JOIN uo_6hr ON uo_6hr.stay_id = index_hour.stay_id
  AND uo_6hr.TIME_INTERVAL_FINISH = index_hour.TIME_INTERVAL_FINISH
  AND uo_6hr.valid_hrs = 6
  LEFT JOIN uo_12hr ON uo_12hr.stay_id = index_hour.stay_id
  AND uo_12hr.TIME_INTERVAL_FINISH = index_hour.TIME_INTERVAL_FINISH
  AND uo_12hr.valid_hrs = 12
  LEFT JOIN uo_24hr ON uo_24hr.stay_id = index_hour.stay_id
  AND uo_24hr.TIME_INTERVAL_FINISH = index_hour.TIME_INTERVAL_FINISH
  AND uo_24hr.valid_hrs = 24