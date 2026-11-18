-- Q2: One row per session (user_pseudo_id + ga_session_id), Nov 2020 - Jan 2021.
-- Finding: 360,129 sessions; scans ~1.1 GB once, every later query runs on this ~12 MB table.
CREATE OR REPLACE TABLE `YOUR_PROJECT.ga4_practice.sessions` AS
WITH ev AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    event_name,
    event_date,
    device.category AS device_category,
    traffic_source.medium AS medium          -- user's FIRST-touch medium, not the session's
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
)
SELECT
  user_pseudo_id,
  ga_session_id,
  MIN(event_date) AS session_date,
  ANY_VALUE(device_category) AS device_category,
  ANY_VALUE(medium) AS medium,
  MAX(IF(event_name = 'view_item', 1, 0))      AS viewed_item,
  MAX(IF(event_name = 'add_to_cart', 1, 0))    AS added_to_cart,
  MAX(IF(event_name = 'begin_checkout', 1, 0)) AS began_checkout,
  MAX(IF(event_name = 'purchase', 1, 0))       AS purchased
FROM ev
WHERE ga_session_id IS NOT NULL
GROUP BY user_pseudo_id, ga_session_id;

-- Data quality check: is add_to_cart reliable?
-- Result: 5,145 of 11,106 checkout sessions (46%) and 2,000 of 4,848 purchase sessions (41%)
-- have no add_to_cart in-session; only 3 purchases lack begin_checkout -> checkout is reliable.
SELECT
  COUNTIF(began_checkout = 1)                       AS checkout_sessions,
  COUNTIF(began_checkout = 1 AND added_to_cart = 0) AS checkout_without_cart,
  COUNTIF(purchased = 1)                            AS purchase_sessions,
  COUNTIF(purchased = 1 AND added_to_cart = 0)      AS purchase_without_cart,
  COUNTIF(purchased = 1 AND began_checkout = 0)     AS purchase_without_checkout
FROM `YOUR_PROJECT.ga4_practice.sessions`;

-- Data quality check: does every checkout session also view a product?
-- Result: 281 of 11,106 checkout sessions (2.5%) have no view_item. The product page -> checkout rate
-- must count only sessions with BOTH events: 10,825 / 77,020 = 14.05% (not 11,106 / 77,020 = 14.42%).
-- In the 4-31 Jan test window: 1,989 / 21,957 = 9.06%.
SELECT
  COUNTIF(viewed_item = 1)                          AS item_view_sessions,
  COUNTIF(began_checkout = 1)                       AS checkout_sessions,
  COUNTIF(began_checkout = 1 AND viewed_item = 0)   AS checkout_without_view,
  COUNTIF(began_checkout = 1 AND viewed_item = 1)   AS checkout_after_view,
  ROUND(100 * COUNTIF(began_checkout = 1 AND viewed_item = 1) / COUNTIF(viewed_item = 1), 2) AS pdp_to_checkout_pct
FROM `YOUR_PROJECT.ga4_practice.sessions`;

-- Traffic level used for test durations
-- Result: 3,914 sessions/day on average (median 3,838, range 2,163-7,562), i.e. ~1,957 per arm in a 50/50 test;
-- 837 item-view sessions/day.
SELECT ROUND(AVG(sessions)) AS avg_sessions_per_day,
       APPROX_QUANTILES(sessions, 2)[OFFSET(1)] AS median_sessions_per_day,
       MIN(sessions) AS min_day, MAX(sessions) AS max_day,
       ROUND(AVG(item_view_sessions)) AS avg_item_view_sessions_per_day
FROM (SELECT session_date, COUNT(*) AS sessions, COUNTIF(viewed_item = 1) AS item_view_sessions
      FROM `YOUR_PROJECT.ga4_practice.sessions` GROUP BY session_date);
