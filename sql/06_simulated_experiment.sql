-- Q6: Simulated H2 experiment (product page -> checkout) on real January 2021 sessions.
-- Finding: the planned 4-week test was underpowered (Jan baseline 9.1% vs 14.4% planned -> 63% power);
-- a true +10% lift was only just detected (p=0.048), and a "hollow" lift was correctly blocked by the guardrail.
--
-- Design: randomise by user (hash of user_pseudo_id), trigger on view_item, run 4 whole weeks
-- (4-31 Jan 2021, after the holiday slump). Three scenarios share the same split:
--   A_true_lift    variant gets +10% relative checkout starts; extra checkouts purchase at the normal rate
--   B_aa_no_effect nothing changes (A/A) - checks the method does not invent winners
--   C_hollow_lift  +10% checkout starts, but none of the extra checkouts purchase
CREATE OR REPLACE TABLE `YOUR_PROJECT.ga4_practice.sim_experiment` AS
WITH base AS (
  SELECT user_pseudo_id, ga_session_id, began_checkout, purchased,
    IF(MOD(ABS(FARM_FINGERPRINT(CONCAT('h2-pdp-test', user_pseudo_id))), 2) = 0, 'control', 'variant') AS arm,
    -- deterministic per-session random numbers, so the simulation is reproducible
    MOD(ABS(FARM_FINGERPRINT(CONCAT(user_pseudo_id, CAST(ga_session_id AS STRING), 'flip'))), 1000000) / 1000000 AS u_flip,
    MOD(ABS(FARM_FINGERPRINT(CONCAT(user_pseudo_id, CAST(ga_session_id AS STRING), 'buy'))), 1000000) / 1000000 AS u_buy
  FROM `YOUR_PROJECT.ga4_practice.sessions`
  WHERE viewed_item = 1 AND session_date BETWEEN '20210104' AND '20210131'
),
rates AS (
  SELECT AVG(began_checkout) AS p0,                                              -- checkout rate
         SAFE_DIVIDE(SUM(purchased * began_checkout), SUM(began_checkout)) AS c0 -- checkout -> purchase
  FROM base
),
scenarios AS (
  SELECT * FROM UNNEST([
    STRUCT('A_true_lift' AS scenario, 0.10 AS lift, TRUE AS carries_to_purchase),
    STRUCT('B_aa_no_effect', 0.0, TRUE),
    STRUCT('C_hollow_lift', 0.10, FALSE)])
)
SELECT s.scenario, b.user_pseudo_id, b.ga_session_id, b.arm,
  -- flip non-checkout variant sessions with prob lift*p0/(1-p0) => +lift relative checkout rate
  IF(b.arm = 'variant' AND b.began_checkout = 0 AND b.u_flip < s.lift * r.p0 / (1 - r.p0), 1, b.began_checkout) AS began_checkout,
  IF(b.arm = 'variant' AND b.began_checkout = 0 AND b.u_flip < s.lift * r.p0 / (1 - r.p0)
     AND s.carries_to_purchase AND b.u_buy < r.c0, 1, b.purchased) AS purchased
FROM base b CROSS JOIN rates r CROSS JOIN scenarios s;

-- Per-arm totals plus user-level sums for delta-method (user-clustered) standard errors.
-- Output saved as analysis/sim_results.csv; statistics in analysis/analyse_experiment.py.
WITH u AS (
  SELECT scenario, arm, user_pseudo_id,
    COUNT(*) AS n, SUM(began_checkout) AS x, SUM(purchased) AS y
  FROM `YOUR_PROJECT.ga4_practice.sim_experiment`
  GROUP BY scenario, arm, user_pseudo_id
)
SELECT scenario, arm,
  COUNT(*) AS users, SUM(n) AS sessions, SUM(x) AS checkouts, SUM(y) AS purchases,
  SUM(n*n) AS sum_n2, SUM(x*x) AS sum_x2, SUM(x*n) AS sum_xn, SUM(y*y) AS sum_y2, SUM(y*n) AS sum_yn
FROM u
GROUP BY scenario, arm
ORDER BY scenario, arm;
