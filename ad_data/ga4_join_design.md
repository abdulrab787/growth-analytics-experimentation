# Design note: joining ad-platform data to GA4

**Status: design only, not an integration.** The two datasets in this repo can't actually be joined. The campaign data (Nykaa, Purplle and Tira, Jul 2024 – Jun 2025) and the GA4 sample (Google Merchandise Store, Nov 2020 – Jan 2021) are different businesses in different years, and the campaign data has no UTM tags. This note describes how I would join them if both came from the same business.

## 1. Goal

Combine what each source does best:

| Source | Knows | Doesn't know |
|---|---|---|
| Ad platforms | Impressions, clicks, **spend** per campaign per day | What users did on the site |
| GA4 | Sessions, funnel steps, **purchases and revenue** on the site | What anything cost |

The joined table gives **cost per GA4-verified purchase and ROAS by campaign, channel and day**, plus the funnel for each campaign's traffic, such as where paid-social visitors drop off compared with email visitors.

## 2. The join key: UTM tags

Every ad's landing URL must carry UTM parameters that follow a fixed naming convention:

| UTM | Value | Example |
|---|---|---|
| `utm_campaign` | The ad platform's campaign ID, lowercase | `ny-cmp-1000` |
| `utm_source` | One channel per URL | `instagram`, `youtube`, `google` |
| `utm_medium` | Channel family | `paid_social`, `cpc`, `email` |

- **Multi-channel campaigns** (67% of rows in this data, for example `"YouTube, Instagram"`) get **one URL per channel**. Then GA4 splits the traffic by `utm_source`, and the ad platform should report spend per channel too. If it only reports total spend, the spend is split equally, as in `channel_roi.py` method B, and the row is flagged.
- **Google Ads auto-tagging** (`gclid`) doesn't put the campaign name in the URL. Use the Google Ads ↔ GA4 link, or enable manual tagging as well.

## 3. Grain and keys

Join at **date × campaign × source**:

```
ads:  date | campaign_key | source | impressions | clicks | spend
ga4:  date | campaign_key | source | sessions | item_views | checkouts | purchases | revenue
```

- **`campaign_key`** = `LOWER(TRIM(campaign))`, using a small mapping table for known mismatches such as renamed or mistyped campaigns.
- **`date`:** GA4 `event_date` is in the **property's** timezone, and ad platforms report in the **ad account's** timezone. Convert both to one timezone before joining, or daily totals will shift between days.

## 4. GA4 side: the campaign for each session

Use the **session's** campaign, not `traffic_source.*`. That field is the user's *first-touch* source, the same pitfall noted in `sql/04`.

```sql
-- One row per session, with its own campaign taken from the session_start event
WITH s AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS date,
    user_pseudo_id,
    (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    LOWER((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'campaign')) AS campaign_key,
    LOWER((SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source'))   AS source
  FROM `project.analytics_XXXX.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20250131'
    AND event_name = 'session_start'
)
-- ...then join to the session funnel flags (as in sql/02) and aggregate to date x campaign_key x source
```

Newer exports also have `collected_traffic_source.manual_campaign_name`. Either way, check the share of sessions with a missing campaign. That share is the untagged traffic.

## 5. Join and metrics

```sql
SELECT a.date, a.campaign_key, a.source,
       a.spend, a.clicks, g.sessions, g.purchases, g.revenue,
       SAFE_DIVIDE(a.spend, g.purchases)  AS cost_per_ga4_purchase,
       SAFE_DIVIDE(g.revenue, a.spend)    AS ga4_roas,
       SAFE_DIVIDE(g.sessions, a.clicks)  AS session_to_click_ratio   -- data-quality signal
FROM ads a
FULL OUTER JOIN ga4 g USING (date, campaign_key, source)
```

A **full outer join** is deliberate, so unmatched rows on either side stay visible instead of disappearing.

## 6. Data-quality checks (each a daily metric)

| Check | Healthy | If it fails |
|---|---|---|
| % of spend with a GA4 match | > 95% | Untagged or mistagged URLs |
| % of paid sessions with an ad-side match | > 95% | Campaign names don't match |
| Sessions ÷ clicks per campaign | about 0.7–1.0 | Under 0.5: tracking or consent loss. Over 1.2: tags reused across campaigns |
| Duplicate keys on each side | 0 | Fix the grain before joining |

## 7. Known disagreements (report them, don't hide them)

- **Conversions won't match.** Ad platforms credit view-through and their own click windows, while GA4 uses its own attribution model. Show both numbers side by side and never add them together.
- **Conversion lag.** A click on day 1 can turn into a purchase on day 5. Report purchases by session date with a fixed window (for example 7 days), and treat the most recent days as incomplete.
- **Undercounting in GA4.** Consent banners and ad blockers hide some sessions, so GA4 ROAS is a lower bound.
- **Currency.** Ad spend may be in INR and GA4 revenue in another currency. Convert at the daily rate before calculating ratios.
- **Correlation, not lift.** This join shows which campaigns *bring in* buyers, not which ones *cause* extra purchases. Causal answers need a holdout test, like the PSA control in `kaggle_ab/`.
