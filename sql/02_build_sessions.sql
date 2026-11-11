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
