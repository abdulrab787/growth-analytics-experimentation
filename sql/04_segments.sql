-- Q4: Where does the funnel leak by segment?
-- Finding: device doesn't matter - all three 95% CIs overlap (desktop 1.27-1.37%, mobile 1.33-1.46%,
-- tablet 1.07-1.57%). By first-touch medium, referral (1.57-1.76%) is clearly above organic (1.04-1.16%);
-- cpc (0.84-1.15%) is too small to separate from organic. Ignore "(data deleted)" - an obfuscation placeholder.
SELECT 'device' AS dim, device_category AS segment,
  COUNT(*) AS sessions,
  SUM(purchased) AS purchases,
  ROUND(100 * SAFE_DIVIDE(SUM(added_to_cart), COUNT(*)), 2) AS cart_rate_pct,
  ROUND(100 * SAFE_DIVIDE(SUM(purchased), COUNT(*)), 2)     AS purchase_rate_pct
FROM `YOUR_PROJECT.ga4_practice.sessions`
GROUP BY device_category
UNION ALL
SELECT 'medium', medium,
  COUNT(*), SUM(purchased),
  ROUND(100 * SAFE_DIVIDE(SUM(added_to_cart), COUNT(*)), 2),
  ROUND(100 * SAFE_DIVIDE(SUM(purchased), COUNT(*)), 2)
FROM `YOUR_PROJECT.ga4_practice.sessions`
GROUP BY medium
HAVING COUNT(*) >= 1000
ORDER BY dim, sessions DESC;

-- Purchase rate by segment with session counts and 95% Wilson confidence intervals
-- (Wilson stays inside 0-100% for small or extreme rates. Sessions from the same user aren't independent,
--  so these intervals are slightly too narrow.)
-- Result (sessions | purchase rate | 95% CI):
--   device   desktop 208,942 | 1.32% | 1.27-1.37   mobile 143,185 | 1.39% | 1.33-1.46   tablet 8,002 | 1.30% | 1.07-1.57
--   medium   organic 122,841 | 1.10% | 1.04-1.16   (none) 83,459 | 1.29% | 1.22-1.37   referral 63,524 | 1.66% | 1.57-1.76
--            <Other> 52,058 | 0.97% | 0.89-1.06    cpc 15,618 | 0.98% | 0.84-1.15
--   user     New 261,238 | 0.68% | 0.65-0.71       Returning 98,891 | 3.10% | 3.00-3.21
WITH seg AS (
  SELECT 'device' AS dimension, device_category AS segment, COUNT(*) AS n, SUM(purchased) AS x
  FROM `YOUR_PROJECT.ga4_practice.sessions` GROUP BY device_category
  UNION ALL
  SELECT 'first-touch medium', medium, COUNT(*), SUM(purchased)
  FROM `YOUR_PROJECT.ga4_practice.sessions` GROUP BY medium HAVING COUNT(*) >= 1000
  UNION ALL
  SELECT 'user type', user_type, COUNT(*), SUM(purchased)
  FROM `YOUR_PROJECT.ga4_practice.sessions_numbered` GROUP BY user_type   -- table from sql/07
),
w AS (SELECT *, x / n AS p, 1.96 AS z FROM seg)
SELECT dimension, segment, n AS sessions, x AS purchases,
  ROUND(100 * p, 2) AS purchase_rate_pct,
  ROUND(100 * (p + z*z/(2*n) - z * SQRT(p*(1-p)/n + z*z/(4*n*n))) / (1 + z*z/n), 2) AS ci_low_pct,
  ROUND(100 * (p + z*z/(2*n) + z * SQRT(p*(1-p)/n + z*z/(4*n*n))) / (1 + z*z/n), 2) AS ci_high_pct
FROM w
ORDER BY dimension, sessions DESC;
