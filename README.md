# Growth Analytics & Experimentation: GA4 Funnel, A/B Testing, Ad ROI

This repo is an end-to-end growth-analytics portfolio project in three parts. It finds where an e-commerce funnel leaks, sizes a test to fix it, reads a real A/B test honestly, and measures what paid channels return. Each part answers a decision question, not just "what happened".

**Stack:** BigQuery (GoogleSQL: CTEs, window functions, `UNNEST`), Python (pandas, statsmodels, scipy, DuckDB), Power BI (PBIP, DAX, Power Query)

| Part | Question | Data | Main output |
|---|---|---|---|
| **1. GA4 funnel** | Where do sessions leak, and what should we test? | GA4 public e-commerce sample, Nov 2020 – Jan 2021 | [test_brief.md](test_brief.md) and the Power BI dashboard |
| **2. Ad campaign A/B test** | Did the ad cause conversions? Ship or not? | Kaggle "Marketing A/B Testing", 588k users | [kaggle_ab/decision_memo.md](kaggle_ab/decision_memo.md) |
| **3. Ad spend ROI** | Which channels return the most, and how would this connect to GA4? | Campaign data from [ecommerce-customer-analytics](https://github.com/abdulrab787/ecommerce-customer-analytics) | [ad_data/ga4_join_design.md](ad_data/ga4_join_design.md) |

## Dashboard (Power BI)

![Funnel page](powerbi/screenshots/01_funnel.png)

| Segments | Trend & Seasonality | Experiment Readout |
|---|---|---|
| ![Segments](powerbi/screenshots/02_segments.png) | ![Trend and seasonality](powerbi/screenshots/03_trend_seasonality.png) | ![Experiment readout](powerbi/screenshots/04_experiment_readout.png) |

It's a 4-page Power BI report saved in PBIP format, with navigation buttons, synced slicers, KPI cards and an insight panel on each page. To open it, see [powerbi/README.md](powerbi/README.md).

## Part 1: GA4 funnel and test planning

**Data:** 92 days, 4.30M events, 270,154 users, 360,129 sessions.

1. **The funnel converts 1.35% of sessions to a purchase.** The biggest losses come before checkout: 21.4% of sessions view a product, and 19.7% of those add to cart.
2. **Returning users convert 4.6 times better:** 3.10% of their sessions purchase, against 0.68% for new users. New users leak most at the last step, where only 29.8% of their checkouts become purchases (59.8% for returning users). New vs returning comes from GA4's `ga_session_number`: numbering sessions with `ROW_NUMBER` inside the data window would mislabel 9,288 users as new.
3. **Add-to-cart isn't reliable.** 46% of checkout sessions have no add-to-cart event in the same session, so the test plan uses `begin_checkout` instead.
4. **Device type doesn't explain the leak.** Purchase rates run from 1.30% to 1.39% across devices. By first-touch medium, referral converts best (1.66%) and cpc worst (0.98%).
5. **Seasonality is strong.** The 7-day purchase rate swings about 4x (0.5% to 2.1%) across Black Friday, December and January. Tests must avoid these windows.
6. **Purchase rate can't be tested at this traffic level.** Detecting a 5% relative lift needs 471,430 sessions per arm, about 35 weeks. The recommended test, which measures product-page-to-checkout rate, can detect a 10% lift in 4 weeks.
7. **The test plan was checked with a simulation.** I ran it on real January sessions in three versions: a real lift, an A/A run and a "hollow" lift. The decision rule shipped the real lift, found nothing in the A/A run and blocked the hollow lift. The simulation also showed the plan was underpowered (63% power instead of 80%), because January's baseline was lower than the three-month average.

## Part 2: Ad campaign A/B test (Kaggle)

- **The 96/4 split** fits a planned 96/4 allocation exactly (p = 1), but would be a severe sample ratio mismatch if 50/50 was intended. It's most likely a deliberate small holdout, which should be confirmed with the campaign owner.
- **Result:** conversion is 2.55% with the ad and 1.79% with the PSA control. That's **+43% relative lift** (95% CI +30% to +58%), z = 7.37, p ≈ 2 × 10⁻¹³, or about 770 extra conversions per 100,000 users.
- **Power:** the 4% holdout can only detect lifts of about 14% or more. A 50/50 split of the same users could detect about 5.5%.
- **The results aren't split by ads seen.** `total_ads` is measured after assignment and tracks engagement: even PSA users, who never saw the ad, convert from 0.4% to 11.9% as their ad count rises.
- **Decision: SHIP (keep the campaign running), with a permanent holdout.** Profitability needs ad cost and order value, which the dataset doesn't include.

## Part 3: Ad spend: cost per conversion and ROI

- **Spend** = `acquisition_cost × conversions`. I checked this against the dataset's own ROI column (r = 0.9999998). Every ratio is calculated from totals: averaging each campaign's ROI gives 2.69, but the true ROI is 1.94.
- **67% of campaigns run on two or more channels.** I attributed them two ways (single-channel campaigns only, and an equal split across channels), and the channel ranking barely changes.
- **No channel is reliably better.** Cost per conversion runs from 168 to 173 (a 2.7% spread), ROI is about 1.9–2.0, and the bootstrap 95% confidence intervals overlap. This data doesn't support moving budget between channels.
- **Joining to GA4 is a design, not an integration:** `campaign_id` becomes `utm_campaign`, joined at date × campaign × source, using the session's campaign rather than first-touch `traffic_source`, with data-quality thresholds. See [ad_data/ga4_join_design.md](ad_data/ga4_join_design.md).

## Repo layout

```
sql/                              Part 1 (BigQuery)
  01_explore_events.sql           events and users per event
  02_build_sessions.sql           one row per session, plus the add-to-cart data quality check
  03_funnel.sql                   step-by-step funnel with LAG drop-off
  04_segments.sql                 conversion by device and first-touch medium
  05_daily_baseline.sql           daily and 7-day rolling purchase rate
  06_simulated_experiment.sql     simulated A/B test (3 scenarios)
  07_new_vs_returning.sql         data profile, ROW_NUMBER session numbering, new vs returning funnel
analysis/                         Part 1 (Python)
  sample_size.py                  sample size and duration for each hypothesis
  analyse_experiment.py           split check, delta-method z-test, Bayesian P(better), guardrails, decision
test_brief.md                     hypotheses, recommended test design, simulated results
powerbi/                          4-page dashboard (PBIP), CSV extracts, screenshots
kaggle_ab/                        Part 2
  analyse_marketing_ab.py         split check, two-proportion test, CIs, power, total_ads diagnostic
  decision_memo.md                one-page ship / don't-ship memo
ad_data/                          Part 3
  channel_roi.py                  CPA, ROAS and ROI by channel, type and brand (DuckDB SQL), bootstrap CIs
  ga4_join_design.md              how to join ad spend to GA4 through UTM tags (design only)
```

## How to run it

**Part 1:** create a BigQuery project (sandbox mode is enough) and a dataset called `ga4_practice` in the **US** location. Replace `YOUR_PROJECT` in each SQL file and run the files in order. Files 02 and 07 each scan about 1 GB once, and later queries run on the small tables they create.

**Part 2:** download `marketing_AB.csv` from [Kaggle](https://www.kaggle.com/datasets/faviovaz/marketing-ab-testing) into `data/`. Raw data isn't committed to the repo.

**Part 3:** the script downloads the campaign data from the ecommerce repo by default.

```
pip install pandas numpy scipy statsmodels duckdb
python analysis/sample_size.py
python analysis/analyse_experiment.py
python kaggle_ab/analyse_marketing_ab.py data/marketing_AB.csv
python ad_data/channel_roi.py
```

## Caveats

- **GA4 sample:** Google obfuscates it, so it has placeholder values and limited internal consistency. Read the rates as a demonstration of the method.
- **First-touch source:** `traffic_source` holds the user's first-touch source, not the session's source.
- **Kaggle dataset:** it has no information collected before assignment, so I couldn't check that the two groups were alike.
- **Campaign data:** it's unusually uniform (exactly 55,555 campaigns per brand), which suggests it's synthetic.
