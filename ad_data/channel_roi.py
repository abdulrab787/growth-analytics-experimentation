"""Cost per conversion and ROI by channel, from the campaign data in the ecommerce-customer-analytics repo.
Usage: python ad_data/channel_roi.py [path_or_url_to_campaign_data_cleaned.csv]

Definitions (checked against the dataset's own ROI column, r = 0.9999998):
  spend = acquisition_cost * conversions      (acquisition_cost is cost per conversion)
  CPA   = SUM(spend) / SUM(conversions)
  ROAS  = SUM(revenue) / SUM(spend)
  ROI   = (SUM(revenue) - SUM(spend)) / SUM(spend)
Ratios are computed from totals, never as an average of per-campaign ratios.
"""
import sys
import duckdb
import pandas as pd

SRC = sys.argv[1] if len(sys.argv) > 1 else (
    "https://raw.githubusercontent.com/abdulrab787/ecommerce-customer-analytics/main/data/processed/campaign_data_cleaned.csv")
camp = pd.read_csv(SRC)
con = duckdb.connect()
con.register("camp", camp)
pd.set_option("display.width", 160)

con.execute("""
CREATE TABLE c AS
SELECT campaign_id, platform, campaign_type, channel_used,
       impressions, clicks, conversions, revenue,
       acquisition_cost * conversions AS spend,
       string_split(channel_used, ', ') AS channels,
       len(string_split(channel_used, ', ')) AS n_channels
FROM camp
""")

KPIS = """
  COUNT(DISTINCT campaign_id)                       AS campaigns,
  ROUND(SUM(spend) / 1e6, 1)                         AS spend_m,
  ROUND(SUM(conversions) / 1e6, 2)                   AS conversions_m,
  ROUND(SUM(spend) / SUM(conversions), 1)            AS cpa,
  ROUND(SUM(revenue) / SUM(spend), 2)                AS roas,
  ROUND((SUM(revenue) - SUM(spend)) / SUM(spend), 2) AS roi,
  ROUND(100.0 * SUM(clicks) / SUM(impressions), 2)   AS ctr_pct,
  ROUND(100.0 * SUM(conversions) / SUM(clicks), 1)   AS click_to_conv_pct
"""

print("=== Data check ===")
print(con.execute("""
SELECT COUNT(*) AS campaigns, MIN(n_channels) AS min_ch, MAX(n_channels) AS max_ch,
       ROUND(100.0 * AVG(CASE WHEN n_channels > 1 THEN 1 ELSE 0 END), 1) AS pct_multi_channel,
       ROUND(SUM(spend) / 1e9, 2) AS total_spend_bn, ROUND(SUM(revenue) / 1e9, 2) AS total_revenue_bn
FROM c""").df().to_string(index=False))

print("\n=== A. By channel: single-channel campaigns only (no attribution needed) ===")
a = con.execute(f"""
SELECT channel_used AS channel, {KPIS}
FROM c WHERE n_channels = 1
GROUP BY channel_used ORDER BY cpa""").df()
print(a.to_string(index=False))

print("\n=== B. By channel: all campaigns, spend/revenue/conversions split equally across listed channels ===")
b = con.execute(f"""
WITH exploded AS (
  SELECT campaign_id, UNNEST(channels) AS channel,
         spend / n_channels AS spend, revenue / n_channels AS revenue,
         conversions / n_channels AS conversions, clicks / n_channels AS clicks,
         impressions / n_channels AS impressions
  FROM c
)
SELECT channel, {KPIS}
FROM exploded GROUP BY channel ORDER BY cpa""").df()
print(b.to_string(index=False))

print("\n=== Ranking stability: does the attribution rule change the answer? ===")
r = a[["channel", "cpa", "roi"]].merge(b[["channel", "cpa", "roi"]], on="channel", suffixes=("_single", "_split"))
r["cpa_rank_single"] = r.cpa_single.rank().astype(int)
r["cpa_rank_split"] = r.cpa_split.rank().astype(int)
print(r.sort_values("cpa_single").to_string(index=False))
spread_a = (a.cpa.max() - a.cpa.min()) / a.cpa.mean()
print(f"CPA spread across channels (single-channel): {spread_a:.1%} of the mean")

print("\n=== C. By campaign type (one value per campaign, so no attribution problem) ===")
print(con.execute(f"SELECT campaign_type, {KPIS} FROM c GROUP BY campaign_type ORDER BY cpa").df().to_string(index=False))

print("\n=== D. By brand platform ===")
print(con.execute(f"SELECT platform, {KPIS} FROM c GROUP BY platform ORDER BY cpa").df().to_string(index=False))

print("\n=== E. Mean of per-campaign ROI vs ROI from totals (why ratios come from totals) ===")
print(con.execute("""
SELECT ROUND(AVG((revenue - spend) / spend), 2) AS mean_of_campaign_roi,
       ROUND((SUM(revenue) - SUM(spend)) / SUM(spend), 2) AS roi_from_totals
FROM c""").df().to_string(index=False))

print("\n=== F. Are the channel CPA gaps real? Bootstrap 95% CI, single-channel campaigns ===")
import numpy as np
rng = np.random.default_rng(42)
single = con.execute("SELECT channel_used AS channel, spend, conversions FROM c WHERE n_channels = 1").df()
rows = []
for ch, g in single.groupby("channel"):
    s, k = g.spend.to_numpy(), g.conversions.to_numpy()
    idx = rng.integers(0, len(g), size=(1000, len(g)))
    boot = s[idx].sum(axis=1) / k[idx].sum(axis=1)
    rows.append((ch, s.sum() / k.sum(), *np.percentile(boot, [2.5, 97.5])))
ci = pd.DataFrame(rows, columns=["channel", "cpa", "ci_low", "ci_high"]).sort_values("cpa").round(1)
print(ci.to_string(index=False))
best, worst = ci.iloc[0], ci.iloc[-1]
print("Best and worst channel intervals overlap" if best.ci_high >= worst.ci_low
      else "Best and worst channel intervals do NOT overlap")
