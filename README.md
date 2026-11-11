# GA4 E-commerce Funnel Analysis & A/B Test Planning

This project analyses the purchase funnel in the public GA4 e-commerce sample in BigQuery, finds where users drop off, and turns the results into an A/B test plan with sample sizes. The plan accounts for data quality and seasonality.

**Stack:** BigQuery (GoogleSQL), Python (statsmodels)
**Data:** `bigquery-public-data.ga4_obfuscated_sample_ecommerce`, Nov 2020 – Jan 2021

## Key findings

1. **The funnel converts 1.35% of sessions to a purchase.** The biggest losses come before checkout: 21.4% of sessions view a product, and 19.7% of those add to cart.
2. **Add-to-cart isn't reliable.** 46% of checkout sessions have no add-to-cart event in the same session, so the test plan uses `begin_checkout` instead.
3. **Device type doesn't explain the leak.** Purchase rates run from 1.30% to 1.39% across devices. By first-touch medium, referral converts best (1.66%) and cpc worst (0.98%).
4. **Seasonality is strong.** The 7-day purchase rate swings about 4x (0.5% to 2.1%) across Black Friday, December and January. Tests must avoid these windows.
5. **Purchase rate can't be tested at this traffic level.** Detecting a 5% lift needs 35 weeks. The recommended test, which measures product-page-to-checkout rate, can detect a 10% lift in 4 weeks.

The full plan is in [test_brief.md](test_brief.md).

## Repo layout

```
sql/
  01_explore_events.sql    events available in the data
  02_build_sessions.sql    one row per session, plus the add-to-cart data quality check
  03_funnel.sql            step-by-step funnel conversion
  04_segments.sql          conversion by device and first-touch medium
  05_daily_baseline.sql    daily and 7-day rolling purchase rate
analysis/
  sample_size.py           sample size and duration for each hypothesis
test_brief.md              hypotheses, recommended test design and decision rule
```

## How to run it

1. Create a BigQuery project. Sandbox mode is enough, with no billing.
2. Create a dataset called `ga4_practice` in the **US** location.
3. Replace `YOUR_PROJECT` in each SQL file with your project ID.
4. Run the SQL files in order. File 02 scans about 1.1 GB once, and every query after it runs on the small table it creates.
5. Run the sample-size script:

```
pip install statsmodels
python analysis/sample_size.py
```

## Caveats

- **Obfuscated data:** Google obfuscates this dataset, so it contains placeholder values and has limited internal consistency. Read the rates as a demonstration of the method, not as real business performance.
- **First-touch source:** `traffic_source` holds the user's first-touch source, not the session's source.
