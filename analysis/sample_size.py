"""Sample size and duration for candidate A/B tests.
Inputs come from sql/03_funnel.sql (Nov 2020 - Jan 2021, 92 days)."""
import math
from statsmodels.stats.power import NormalIndPower
from statsmodels.stats.proportion import proportion_effectsize

DAYS = 92
SESSIONS = 360_129
ITEM_VIEW_SESSIONS = 77_020
CART_SESSIONS = 15_188
CHECKOUT_SESSIONS = 11_106
PURCHASE_SESSIONS = 4_848

# (name, numerator, eligible population = who enters the test, relative lifts)
tests = [
    ("Purchase rate, all sessions",            PURCHASE_SESSIONS,  SESSIONS,            [0.05, 0.10, 0.20]),
    ("H1 View-item rate, all sessions",        ITEM_VIEW_SESSIONS, SESSIONS,            [0.03, 0.05]),
    ("H2 Checkout rate, item-view sessions",   CHECKOUT_SESSIONS,  ITEM_VIEW_SESSIONS,  [0.05, 0.10]),
    ("H3 Purchase rate, checkout sessions",    PURCHASE_SESSIONS,  CHECKOUT_SESSIONS,   [0.05, 0.10]),
]

print(f"{'test':42} {'base':>7} {'lift':>5} {'n/arm':>9} {'days':>5} {'weeks':>5}")
for name, num, pop, lifts in tests:
    p = num / pop
    per_day = pop / DAYS
    for lift in lifts:
        es = proportion_effectsize(p * (1 + lift), p)
        n = NormalIndPower().solve_power(effect_size=es, alpha=0.05, power=0.8,
                                         ratio=1, alternative="two-sided")
        days = 2 * n / per_day
        print(f"{name:42} {p:7.2%} {lift:5.0%} {round(n):9,} {math.ceil(days):5} {math.ceil(days/7):5}")
