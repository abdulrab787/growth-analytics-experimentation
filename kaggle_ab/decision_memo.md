# Decision memo: keep the ad campaign running?

**Data:** Kaggle "Marketing A/B Testing" (faviovaz). 588,101 users, each assigned to the **ad** group (saw the campaign ad) or the **psa** group (saw a public service announcement in the same slots, which is the control).
**Analysis:** `kaggle_ab/analyse_marketing_ab.py`. The full output is in `kaggle_ab/results.txt`.

## Decision: SHIP (keep the campaign running), but keep a holdout

The ad caused more conversions. The lift is large, very unlikely to be chance, and stays clearly positive even at the bottom of its confidence interval. Whether it is *profitable* can't be judged from this data, because it has no ad cost or order value.

## Result

| | Users | Conversions | Conversion rate |
|---|---|---|---|
| Ad (treatment) | 564,577 | 14,423 | **2.55%** |
| PSA (control) | 23,524 | 420 | **1.79%** |

- **Absolute lift:** +0.77 percentage points (95% CI +0.60 to +0.94 pp)
- **Relative lift:** **+43%** (95% CI +30% to +58%)
- **Two-proportion z-test:** z = 7.37, p ≈ 2 × 10⁻¹³
- **Business impact:** about **770 extra conversions per 100,000 users** shown the ad (95% CI 595 to 943)

## Checks before trusting it

1. **The 96/4 split.** 96.00% of users are in ad and 4.00% in psa. Against a 50/50 plan this would be an extreme sample ratio mismatch (p ≈ 0). Against a 96/4 plan it fits exactly (p = 1).
   - **What it most likely means:** a deliberate small holdout. The business wanted most users to see the ad, which is common practice for campaigns.
   - **What would make it a problem:** if the split *wasn't* planned, users were assigned to groups in some biased way. The dataset has no information collected before assignment, so I can't check whether the two groups were alike. **Action:** confirm the planned split with whoever ran the campaign before quoting the result.
2. **Power.** The small holdout limits precision. This design can only reliably detect lifts of about **14%** or more, where a 50/50 split of the same users could detect about **5.5%**. The real lift is large enough that this doesn't change the decision, but it's why the confidence interval is wide (30% to 58%).
3. **No segmenting by `total_ads`.** The number of ads seen is measured *after* assignment, and it follows engagement. Even in the PSA group, which saw no ad, conversion rises from 0.4% for users with 1–10 ads to 11.9% for users with 100+. Splitting the lift by ad count would compare users who differ in engagement, not in the ad, so I report only the overall comparison between the randomised groups.

## Limits

- **No cost or revenue,** so return on ad spend (ROAS) can't be calculated. Shipping is justified on effect alone. The budget decision needs cost per incremental conversion, which is spend ÷ (number of users × 0.77 pp).
- **One conversion flag, no time window.** "Converted" isn't defined in the dataset, so there's no guardrail metric such as refunds or unsubscribes.
- **Point-in-time result.** An ad's effect usually fades as users see it repeatedly.

## Next steps

1. Confirm the planned 96/4 allocation with the campaign owner.
2. **Keep a permanent 4–5% PSA holdout** so the effect is measured continuously, not assumed.
3. Get spend and order value, then report incremental ROAS. That number decides the budget, not just whether to ship.
