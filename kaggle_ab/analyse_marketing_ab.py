"""Kaggle 'Marketing A/B Testing' (faviovaz): did the ad campaign cause conversions?
Groups: 'ad' (saw the ad) vs 'psa' (saw a public service announcement instead = control).
Usage: python analysis/analyse_marketing_ab.py data/marketing_AB.csv
"""
import sys
import numpy as np
import pandas as pd
from scipy import stats
from statsmodels.stats.proportion import proportions_ztest, confint_proportions_2indep, proportion_effectsize
from statsmodels.stats.power import NormalIndPower

path = sys.argv[1] if len(sys.argv) > 1 else "data/marketing_AB.csv"
df = pd.read_csv(path, index_col=0)
df.columns = [c.strip().replace(" ", "_") for c in df.columns]

print("=== 1. Data checks ===")
print(f"rows {len(df):,} | duplicate user_id {df.user_id.duplicated().sum()} | nulls {int(df.isna().sum().sum())}")
print("groups:", df.test_group.value_counts().to_dict(), "| converted values:", sorted(df.converted.unique()))

print("\n=== 2. The 96/4 split ===")
n = df.test_group.value_counts()
share = n / n.sum()
print(f"ad {n['ad']:,} ({share['ad']:.2%}) | psa {n['psa']:,} ({share['psa']:.2%})")
chi_5050 = stats.chisquare([n["ad"], n["psa"]])
print(f"vs an intended 50/50: chi-square p = {chi_5050.pvalue:.1e}  -> only an SRM if 50/50 was the plan")
for planned in (0.95, 0.96):
    p = stats.chisquare([n["ad"], n["psa"]], f_exp=[n.sum() * planned, n.sum() * (1 - planned)]).pvalue
    print(f"vs an intended {planned:.0%}/{1-planned:.0%}: chi-square p = {p:.3g}")
print("No pre-treatment covariates exist (total_ads, most_ads_day/hour are all measured after assignment),")
print("so covariate balance between groups cannot be checked.")

print("\n=== 3. Two-proportion test (ad vs psa) ===")
g = df.groupby("test_group").converted.agg(["sum", "count"])
x_t, n_t = int(g.loc["ad", "sum"]), int(g.loc["ad", "count"])
x_c, n_c = int(g.loc["psa", "sum"]), int(g.loc["psa", "count"])
p_t, p_c = x_t / n_t, x_c / n_c
z, p_val = proportions_ztest([x_t, x_c], [n_t, n_c], alternative="two-sided")
lo, hi = confint_proportions_2indep(x_t, n_t, x_c, n_c, method="wald", compare="diff")
rlo, rhi = confint_proportions_2indep(x_t, n_t, x_c, n_c, method="log", compare="ratio")
print(f"ad  : {x_t:,}/{n_t:,} = {p_t:.4%}")
print(f"psa : {x_c:,}/{n_c:,} = {p_c:.4%}")
print(f"absolute diff {p_t - p_c:+.4%} (95% CI {lo:+.4%} to {hi:+.4%})")
print(f"relative lift {p_t / p_c - 1:+.1%} (95% CI {rlo - 1:+.1%} to {rhi - 1:+.1%})")
print(f"z = {z:.2f}, p = {p_val:.2e}")
print(f"incremental conversions per 100k users shown ads: {(p_t - p_c) * 100_000:,.0f} "
      f"(95% CI {lo * 100_000:,.0f} to {hi * 100_000:,.0f})")

print("\n=== 4. Power with this split ===")
k = n_t / n_c
mde_es = NormalIndPower().solve_power(nobs1=n_c, ratio=k, alpha=0.05, power=0.8)
# convert Cohen's h back to a relative lift around the control rate
target = np.sin(np.arcsin(np.sqrt(p_c)) + mde_es / 2) ** 2
print(f"minimum detectable relative lift at 80% power: {target / p_c - 1:+.1%}")
n_5050 = n.sum() / 2
mde_5050 = NormalIndPower().solve_power(nobs1=n_5050, ratio=1, alpha=0.05, power=0.8)
t2 = np.sin(np.arcsin(np.sqrt(p_c)) + mde_5050 / 2) ** 2
print(f"same total users split 50/50 would detect: {t2 / p_c - 1:+.1%}  (the small holdout is the binding constraint)")

print("\n=== 5. Why NOT to segment by total_ads (diagnostic only) ===")
df["ads_band"] = pd.cut(df.total_ads, [0, 10, 25, 50, 100, 10_000], labels=["1-10", "11-25", "26-50", "51-100", "100+"])
tab = df.pivot_table(index="ads_band", columns="test_group", values="converted", aggfunc="mean", observed=True)
print((tab * 100).round(2).to_string())
print("Conversion climbs steeply with total_ads in the PSA group too, where no ad was shown:")
print("heavier users both see more impressions and convert more. total_ads is a consequence of")
print("engagement (and of treatment), so lift 'within ad bands' compares non-comparable users.")
print(f"median total_ads: ad {df[df.test_group=='ad'].total_ads.median():.0f}, psa {df[df.test_group=='psa'].total_ads.median():.0f}")
