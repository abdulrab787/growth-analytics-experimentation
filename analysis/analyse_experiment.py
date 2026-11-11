"""Read the simulated H2 experiment (sql/06_simulated_experiment.sql output).

Randomisation unit = user, analysis unit = session, so per-arm rates are ratio
metrics. Standard errors use the delta method on user-level sums (cluster-robust),
not the naive binomial formula, which would understate variance.
"""
import csv, math
import numpy as np
from scipy import stats
from statsmodels.stats.power import NormalIndPower
from statsmodels.stats.proportion import proportion_effectsize

rows = list(csv.DictReader(open("analysis/sim_results.csv")))
for r in rows:
    for k, v in r.items():
        if k not in ("scenario", "arm"):
            r[k] = int(v)

def ratio_stats(r, num, sq, cross):
    """Session-level rate and its delta-method variance with user clustering."""
    N = r["users"]
    n_bar = r["sessions"] / N
    x_bar = r[num] / N
    R = r[num] / r["sessions"]
    var_n = r["sum_n2"] / N - n_bar**2
    var_x = r[sq] / N - x_bar**2
    cov = r[cross] / N - x_bar * n_bar
    var_R = (var_x - 2 * R * cov + R**2 * var_n) / (N * n_bar**2)
    return R, var_R

def compare(c, v, num, sq, cross):
    rc, vc = ratio_stats(c, num, sq, cross)
    rv, vv = ratio_stats(v, num, sq, cross)
    diff = rv - rc
    se = math.sqrt(vc + vv)
    z = diff / se
    p = 2 * (1 - stats.norm.cdf(abs(z)))
    lift = rv / rc - 1
    # CI on the absolute difference, expressed relative to control (consistent with p)
    return rc, rv, lift, (diff - 1.96 * se) / rc, (diff + 1.96 * se) / rc, p

def bayes(c, v, num, draws=200_000, seed=7):
    rng = np.random.default_rng(seed)
    pc = rng.beta(1 + c[num], 1 + c["sessions"] - c[num], draws)
    pv = rng.beta(1 + v[num], 1 + v["sessions"] - v[num], draws)
    return (pv > pc).mean(), np.maximum(pc - pv, 0).mean()  # P(variant better), expected loss

def srm(c, v):
    chi2, p = stats.chisquare([c["users"], v["users"]])
    return p

def decide(p_primary, lift_primary, p_guard, lift_guard):
    if p_primary < 0.05 and lift_primary > 0:
        if lift_guard < 0:  # guardrail must not move the wrong way
            return "DON'T SHIP - checkout up but purchases did not follow"
        return "SHIP"
    return "KEEP CONTROL - no detectable effect"

scen = sorted({r["scenario"] for r in rows})
for s in scen:
    c = next(r for r in rows if r["scenario"] == s and r["arm"] == "control")
    v = next(r for r in rows if r["scenario"] == s and r["arm"] == "variant")
    print(f"\n=== {s} ===")
    print(f"SRM check (users {c['users']:,} vs {v['users']:,}): p = {srm(c, v):.3f}"
          + ("  -> OK" if srm(c, v) > 0.01 else "  -> SAMPLE RATIO MISMATCH, stop"))
    out = {}
    for label, num, sq, cross in [("Checkout rate (primary)", "checkouts", "sum_x2", "sum_xn"),
                                  ("Purchase rate (guardrail)", "purchases", "sum_y2", "sum_yn")]:
        rc, rv, lift, lo, hi, p = compare(c, v, num, sq, cross)
        pb, loss = bayes(c, v, num)
        out[num] = (p, lift)
        print(f"{label:27} control {rc:6.2%}  variant {rv:6.2%}  lift {lift:+6.1%} "
              f"[{lo:+.1%}, {hi:+.1%}]  p={p:.3f}  P(variant>control)={pb:.1%}  exp.loss={loss*100:.3f}pp")
    # guardrail: purchase rate among sessions that started checkout
    cr_c, cr_v = c["purchases"] / c["checkouts"], v["purchases"] / v["checkouts"]
    print(f"{'Checkout->purchase':27} control {cr_c:6.2%}  variant {cr_v:6.2%}")
    print("Decision:", decide(*out["checkouts"], *out["purchases"]))

# Power actually achieved in the January window (baseline differed from the plan)
c = rows[0]
p0 = c["checkouts"] / c["sessions"]
n_arm = (rows[0]["sessions"] + rows[1]["sessions"]) / 2
es = proportion_effectsize(p0 * 1.10, p0)
power = NormalIndPower().power(effect_size=es, nobs1=n_arm, alpha=0.05)
need = NormalIndPower().solve_power(effect_size=es, alpha=0.05, power=0.8)
print(f"\nJanuary baseline {p0:.2%} (plan assumed 14.42%). Power to detect +10% with "
      f"{n_arm:,.0f} sessions/arm = {power:.0%}; 80% power needs {need:,.0f}/arm.")
