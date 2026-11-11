-- Q5: Daily purchase rate and 7-day rolling rate (baseline + variance for test planning).
-- Finding: the 7-day rate swings ~4x - from ~0.8% (early Nov) to ~2.0% (late Nov - mid Dec,
-- Cyber Monday peak 2.75%) down to ~0.5% (late Dec - mid Jan); tests must avoid these windows.
WITH daily AS (
  SELECT PARSE_DATE('%Y%m%d', session_date) AS day,
         COUNT(*) AS sessions,
         SUM(purchased) AS purchases
  FROM `YOUR_PROJECT.ga4_practice.sessions`
  GROUP BY day
)
SELECT day, sessions, purchases,
  ROUND(100 * SAFE_DIVIDE(purchases, sessions), 2) AS daily_rate_pct,
  ROUND(100 * SAFE_DIVIDE(
    SUM(purchases) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),
    SUM(sessions)  OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)), 2) AS rolling_7d_rate_pct
FROM daily
ORDER BY day;
