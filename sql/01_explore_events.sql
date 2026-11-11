-- Q1: Which events exist in the GA4 sample (Nov 2020)?
-- Finding: all five funnel events exist, but add_to_cart users (2,060) < begin_checkout users (4,219),
-- so add_to_cart is under-recorded and should not be a primary metric.
SELECT event_name,
       COUNT(*) AS events,
       COUNT(DISTINCT user_pseudo_id) AS users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20201130'
GROUP BY event_name
ORDER BY events DESC;
