-- Q7: Data profile, session numbering with ROW_NUMBER, and the funnel for new vs returning users.
-- Finding: returning-user sessions purchase at 3.10% vs 0.68% for new users (4.6x). New users leak most at
-- checkout -> purchase (29.8% vs 59.8%). ROW_NUMBER within the window mislabels 9,288 users as new,
-- so new vs returning comes from GA4's ga_session_number.

-- 7a. Profile of the whole window
-- Result: 2020-11-01 to 2021-01-31 (92 days), 4,295,584 events, 270,154 users, 360,129 sessions,
--         17 event types, 15.9 events per user.
SELECT
  MIN(PARSE_DATE('%Y%m%d', event_date)) AS first_day,
  MAX(PARSE_DATE('%Y%m%d', event_date)) AS last_day,
  COUNT(DISTINCT event_date) AS days,
  COUNT(*) AS events,
  COUNT(DISTINCT user_pseudo_id) AS users,
  COUNT(DISTINCT CONCAT(user_pseudo_id, '-', CAST(
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING))) AS sessions,
  COUNT(DISTINCT event_name) AS event_types,
  ROUND(COUNT(*) / COUNT(DISTINCT user_pseudo_id), 1) AS events_per_user
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131';

-- 7b. One row per session, numbered per user with ROW_NUMBER (scans ~1 GB once)
CREATE OR REPLACE TABLE `YOUR_PROJECT.ga4_practice.sessions_numbered` AS
WITH ev AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS ga_session_number,
    event_timestamp,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
s AS (
  SELECT user_pseudo_id, ga_session_id,
    MIN(event_timestamp) AS session_start_ts,
    MAX(ga_session_number) AS ga_session_number,      -- GA4's lifetime session count for the user
    MAX(IF(event_name = 'view_item', 1, 0))      AS viewed_item,
    MAX(IF(event_name = 'add_to_cart', 1, 0))    AS added_to_cart,
    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS began_checkout,
    MAX(IF(event_name = 'purchase', 1, 0))       AS purchased
  FROM ev
  WHERE ga_session_id IS NOT NULL
  GROUP BY user_pseudo_id, ga_session_id
)
SELECT *,
  ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY session_start_ts) AS session_seq_in_window,
  IF(ga_session_number = 1, 'New', 'Returning') AS user_type
FROM s;

-- 7c. Why not use ROW_NUMBER alone for new vs returning?
-- Result: 270,154 users; 47,364 have 2+ sessions in the window. 9,288 users' first session in the window
--         is already a returning visit (they came before 1 Nov), so window numbering would call them "new".
--         372 sessions have ga_session_number = 1 but are not the user's first in the window (obfuscation noise).
SELECT
  COUNT(*) AS sessions,
  COUNTIF(ga_session_number IS NULL) AS missing_session_number,
  COUNTIF(session_seq_in_window = 1) AS first_session_in_window,
  COUNTIF(session_seq_in_window = 1 AND ga_session_number > 1) AS first_in_window_but_returning,
  COUNTIF(ga_session_number = 1 AND session_seq_in_window > 1) AS new_but_not_first_in_window,
  COUNT(DISTINCT user_pseudo_id) AS users,
  COUNT(DISTINCT IF(session_seq_in_window > 1, user_pseudo_id, NULL)) AS users_with_2plus_sessions
FROM `YOUR_PROJECT.ga4_practice.sessions_numbered`;

-- 7d. Funnel by user type, with LAG drop-off inside each segment
-- Result:
--   New:       261,238 -> 52,171 (20.0%) -> 8,853 (17.0%) -> 5,974 (67.5%) -> 1,780 (29.8%)  = 0.68% purchase
--   Returning:  98,891 -> 24,849 (25.1%) -> 6,335 (25.5%) -> 5,132 (81.0%) -> 3,068 (59.8%)  = 3.10% purchase
WITH agg AS (
  SELECT user_type,
    COUNT(*) AS sessions, SUM(viewed_item) AS v, SUM(added_to_cart) AS c,
    SUM(began_checkout) AS b, SUM(purchased) AS p
  FROM `YOUR_PROJECT.ga4_practice.sessions_numbered`
  GROUP BY user_type
),
steps AS (
  SELECT user_type, s.step, s.step_name, s.n
  FROM agg, UNNEST([
    STRUCT(1 AS step, 'Sessions' AS step_name, sessions AS n),
    STRUCT(2, 'Viewed item', v),
    STRUCT(3, 'Added to cart', c),
    STRUCT(4, 'Began checkout', b),
    STRUCT(5, 'Purchased', p)]) AS s
)
SELECT user_type, step, step_name, n,
  ROUND(100 * SAFE_DIVIDE(n, LAG(n) OVER (PARTITION BY user_type ORDER BY step)), 1) AS pct_of_previous_step,
  ROUND(100 * SAFE_DIVIDE(n, FIRST_VALUE(n) OVER (PARTITION BY user_type ORDER BY step)), 2) AS pct_of_sessions
FROM steps
ORDER BY user_type, step;
