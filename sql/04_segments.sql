-- Q4: Where does the funnel leak by segment?
-- Finding: device barely matters (1.30-1.39% purchase rate); by first-touch medium, referral converts
-- best (1.66%) and cpc worst (0.98%). Ignore "(data deleted)" (3.12%) - an obfuscation placeholder.
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
