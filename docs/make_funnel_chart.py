"""Funnel chart for the README (single series, so one hue and no legend)."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

steps = ["Sessions", "Viewed item", "Added to cart*", "Began checkout", "Purchased"]
n = [360_129, 77_020, 15_188, 11_106, 4_848]
conv = [None, 21.4, 19.7, 73.1, 43.7]
INK, MUTED, BAR, GRID = "#1F2937", "#6B7280", "#1F6FB2", "#E5E7EB"

fig, ax = plt.subplots(figsize=(9, 4.2), dpi=160)
ax.set_xlim(0, 360_129 * 1.32); ax.set_ylim(-0.6, len(steps) - 0.4); ax.invert_yaxis()
h = 0.56
for i, v in enumerate(n):
    ax.add_patch(FancyBboxPatch((0, i - h / 2), v, h, boxstyle="round,pad=0,rounding_size=4",
                                mutation_aspect=1 / 60_000, linewidth=0, facecolor=BAR))
    pct_all = 100 * v / n[0]
    ax.text(v + 6_000, i, f"{v:,}  ({pct_all:.2f}% of sessions)" if i else f"{v:,}",
            va="center", ha="left", fontsize=9.5, color=INK)
    yx = ax.get_yaxis_transform()
    ax.text(-0.03, i, steps[i], transform=yx, va="center", ha="right", fontsize=10.5, color=INK)
    if conv[i] is not None:
        ax.text(-0.03, i - 0.5, f"↓ {conv[i]}% of previous step", transform=yx,
                va="center", ha="right", fontsize=8, color=MUTED)
ax.set_yticks([]); ax.set_xticks([])
for s in ax.spines.values(): s.set_visible(False)
ax.axvline(0, color=GRID, lw=1)
fig.suptitle("GA4 purchase funnel, Nov 2020 – Jan 2021 (sessions reaching each step)",
             x=0.02, ha="left", fontsize=12, color=INK, fontweight="bold")
fig.text(0.02, 0.02, "* add_to_cart is under-recorded: 46% of checkout sessions have no add-to-cart event. "
         "Source: sql/03_funnel.sql", fontsize=7.5, color=MUTED)
fig.subplots_adjust(left=0.24, right=0.98, top=0.88, bottom=0.10)
fig.savefig("funnel.png", facecolor="white")
