"""Sample size and duration for candidate A/B tests.
Inputs come from sql/02 and sql/03 (Nov 2020 - Jan 2021, 92 days), checked in sql/02's data-quality queries.

Each rate is "sessions that reached step B after reaching step A / sessions that reached step A":
281 checkout sessions (2.5%) have no view_item, so they are excluded from the product-page -> checkout
numerator. Counting all checkouts would overstate the baseline (14.42% instead of 14.05%).
"""
import math
from statsmodels.stats.power import NormalIndPower
from statsmodels.stats.proportion import proportion_effectsize

DAYS = 92
SESSIONS = 360_129
ITEM_VIEW_SESSIONS = 77_020
CHECKOUT_SESSIONS = 11_106
CHECKOUT_AFTER_VIEW = 10_825      # began_checkout AND viewed_item in the same session
PURCHASE_SESSIONS = 4_848
PURCHASE_AFTER_CHECKOUT = 4_845   # purchased AND began_checkout (3 purchases had no checkout)

# January test window (4-31 Jan 2021, 28 days), used by the simulation in sql/06
JAN_DAYS, JAN_ITEM_VIEW, JAN_CHECKOUT_AFTER_VIEW = 28, 21_957, 1_989

print("=== Inputs ===")
print(f"sessions per day          {SESSIONS / DAYS:,.0f}  (per arm in a 50/50 test: {SESSIONS / DAYS / 2:,.0f})")
print(f"item-view sessions per day {ITEM_VIEW_SESSIONS / DAYS:,.0f}")
print(f"purchase rate             {PURCHASE_SESSIONS / SESSIONS:.2%}")
print(f"product page -> checkout  {CHECKOUT_AFTER_VIEW / ITEM_VIEW_SESSIONS:.2%}  (3-month)  |  "
      f"{JAN_CHECKOUT_AFTER_VIEW / JAN_ITEM_VIEW:.2%}  (4-31 Jan)")
print("alpha 0.05, power 0.80, two-sided, 50/50 split\n")

# (name, numerator, eligible population, days observed, relative lifts)
tests = [
    ("Purchase rate, all sessions",               PURCHASE_SESSIONS,       SESSIONS,           DAYS,     [0.05, 0.10, 0.20]),
    ("H1 View-item rate, all sessions",           ITEM_VIEW_SESSIONS,      SESSIONS,           DAYS,     [0.03, 0.05]),
    ("H2 Checkout rate, item-view sessions",      CHECKOUT_AFTER_VIEW,     ITEM_VIEW_SESSIONS, DAYS,     [0.05, 0.10]),
    ("H2 same, January test window",              JAN_CHECKOUT_AFTER_VIEW, JAN_ITEM_VIEW,      JAN_DAYS, [0.05, 0.10]),
    ("H3 Purchase rate, checkout sessions",       PURCHASE_AFTER_CHECKOUT, CHECKOUT_SESSIONS,  DAYS,     [0.05, 0.10]),
]

print(f"{'test':40} {'base':>7} {'lift':>5} {'n/arm':>9} {'days':>5} {'weeks':>5}")
for name, num, pop, days_obs, lifts in tests:
    p = num / pop
    per_day = pop / days_obs
    for lift in lifts:
        es = proportion_effectsize(p * (1 + lift), p)
        n = NormalIndPower().solve_power(effect_size=es, alpha=0.05, power=0.8,
                                         ratio=1, alternative="two-sided")
        days = 2 * n / per_day
        print(f"{name:40} {p:7.2%} {lift:5.0%} {round(n):9,} {math.ceil(days):5} {math.ceil(days/7):5}")
