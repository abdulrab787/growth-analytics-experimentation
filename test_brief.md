# A/B Test Brief: Product page → checkout

**Dataset:** Google Merchandise Store GA4 sample (obfuscated), Nov 2020 – Jan 2021, 360,129 sessions
**Status:** Planning exercise. The data is obfuscated, so the rates show the method, not real business performance.

## 1. Where the funnel leaks

| Step | Sessions | % of previous step | % of all sessions |
|---|---|---|---|
| Sessions | 360,129 | – | 100% |
| Viewed item | 77,020 | 21.4% | 21.39% |
| Added to cart | 15,188 | 19.7% | 4.22% |
| Began checkout | 11,106 | 73.1% | 3.08% |
| Purchased | 4,848 | 43.7% | 1.35% |

- The biggest losses happen before checkout. 79% of sessions never view a product, and only 14.4% of product-viewing sessions start checkout.
- Device type doesn't explain the leak. Desktop, mobile and tablet purchase rates are all between 1.30% and 1.39%.
- Purchase rate by first-touch medium runs from 0.98% (cpc) to 1.66% (referral). `traffic_source` is the user's first-touch source, so these rates can't be read as session-level channel performance.

## 2. Data quality: why add-to-cart can't be the primary metric

46% of checkout sessions and 41% of purchase sessions have no `add_to_cart` event in the same session. This could be under-tracking, or carts built in an earlier session. Either way, a test metric built on `add_to_cart` would measure tracking noise. `begin_checkout` is reliable: only 3 of 4,848 purchase sessions lack it.

## 3. Hypotheses

| # | Hypothesis | Primary metric | Who enters the test | Baseline | Detectable lift | Duration |
|---|---|---|---|---|---|---|
| H1 | Putting products on landing and home pages (instead of promos) raises the share of sessions that view a product | View-item rate | All sessions | 21.4% | +5% relative | 2 weeks |
| **H2** | **Showing delivery cost, delivery date and stock on the product page reduces hesitation and raises checkout starts** | **Begin-checkout rate** | **Sessions that view an item** | **14.4%** | **+10% relative** | **4 weeks** |
| H3 | Guest checkout and fewer form fields raise checkout completion | Purchase rate | Sessions that begin checkout | 43.7% | +10% relative | 5 weeks |

Sample sizes use alpha 0.05, 80% power, a two-sided test and a 50/50 split. They come from `analysis/sample_size.py`.

**Recommendation: run H2 first.** It targets the largest leak that's still close to revenue, uses a reliably tracked event, and can detect a 10% lift in 4 weeks. H1 is faster, but it's furthest from revenue. H3 would take 5 weeks to detect a 10% lift, and 20 weeks for 5%, because so few sessions reach checkout.

For comparison, testing overall purchase rate would need 471k sessions per arm (35 weeks) to detect a 5% lift. That isn't feasible at about 3,900 sessions a day.

## 4. Test design (H2)

- **Unit of randomisation:** user (`user_pseudo_id`), so a returning visitor always sees the same variant. Analysis is per session, so report a user-clustered standard error, or switch to user-level rates.
- **Trigger:** a user enters the test on their first `view_item`. Sessions with no product view are excluded.
- **Primary metric:** sessions with `begin_checkout` ÷ sessions with `view_item`.
- **Guardrail metrics:** purchase rate per triggered session, revenue per triggered session, and checkout-to-purchase rate. A variant that pulls more people into checkout but loses them there doesn't count as a win.
- **Sample:** about 9,700 triggered sessions per arm, about 4 weeks at the current traffic level.
- **Timing:** run whole weeks only, and avoid mid-November to mid-January. The 7-day purchase rate swings about 4x across Black Friday, Cyber Monday, December and the post-holiday slump.
- **Stopping rule:** decide the duration in advance and don't stop early on a significant result. If you need to check results mid-test, use a sequential method such as mSPRT.
- **Pre-launch checks:** an A/A test or sample ratio mismatch (SRM) check, plus confirming that `view_item` and `begin_checkout` fire the same way in both variants.

## 5. Decision rule

| Result | Action |
|---|---|
| Primary metric up significantly and guardrails flat or up | Ship |
| Primary metric up but purchase rate down | Don't ship. Investigate the checkout step |
| Not significant | Keep the control. Record the minimum detectable effect so nobody reads "no effect" into it |

## 6. Caveats

- The dataset is obfuscated: it has placeholder values such as `<Other>` and `(data deleted)`, and its internal consistency is limited.
- The funnel counts sessions that reached each step, not a strict sequence.
- Medium is first-touch, not session-level.
