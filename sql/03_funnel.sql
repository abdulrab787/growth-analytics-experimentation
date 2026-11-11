-- Q3: Session funnel with step-to-step conversion ("reached the step", not strict sequence).
-- Finding: 1.35% of sessions purchase; the biggest leaks are at the top -
-- only 21.4% of sessions view a product and 19.7% of those add to cart.
WITH funnel AS (
  SELECT 1 AS step, 'Sessions' AS step_name, COUNT(*) AS n FROM `YOUR_PROJECT.ga4_practice.sessions`
  UNION ALL SELECT 2, 'Viewed item',    SUM(viewed_item)    FROM `YOUR_PROJECT.ga4_practice.sessions`
  UNION ALL SELECT 3, 'Added to cart',  SUM(added_to_cart)  FROM `YOUR_PROJECT.ga4_practice.sessions`
  UNION ALL SELECT 4, 'Began checkout', SUM(began_checkout) FROM `YOUR_PROJECT.ga4_practice.sessions`
  UNION ALL SELECT 5, 'Purchased',      SUM(purchased)      FROM `YOUR_PROJECT.ga4_practice.sessions`
)
SELECT step, step_name, n,
  ROUND(100 * SAFE_DIVIDE(n, LAG(n) OVER (ORDER BY step)), 1)          AS pct_of_previous_step,
  ROUND(100 * SAFE_DIVIDE(n, FIRST_VALUE(n) OVER (ORDER BY step)), 2)  AS pct_of_all_sessions
FROM funnel
ORDER BY step;
-- Result: 360,129 -> 77,020 (21.4%) -> 15,188 (19.7%) -> 11,106 (73.1%) -> 4,848 (43.7%)
