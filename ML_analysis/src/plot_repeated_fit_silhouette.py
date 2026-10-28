"""Create the fresh repeated-fit silhouette figures from saved embeddings."""

from pathlib import Path
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import numpy as np
import pandas as pd
from scipy.stats import ttest_ind


SRC = Path.cwd()
if SRC.name != "src" and (SRC / "src").exists():
    SRC = SRC / "src"
OUTPUT = SRC / "silhouette_repeated_fit_outputs"
SCORES_FILE = OUTPUT / "silhouette_repeated_fit_scores.csv"
if not SCORES_FILE.exists():
    raise FileNotFoundError(
        f"Missing {SCORES_FILE}. Run run_repeated_fit_silhouette.py first."
    )

PHASES = ["rest", "meditation", "music", "movie"]
PHASE_LABELS = ["Rest", "Meditation", "Music", "Movie"]
PHASE_COLORS = {
    "rest": "deeppink", "meditation": "darkblue",
    "music": "darkgreen", "movie": "orange",
}
CONDITIONS = ["No psilocybin", "Psilocybin"]
# True six lowest and six highest classification accuracies calculated from
# the saved published embeddings, in increasing-MEQ display order.
LOW_INDICES = [4, 26, 45, 8, 19, 27]
HIGH_INDICES = [39, 51, 35, 22, 53, 32]
STABILITY_ORDER = LOW_INDICES + HIGH_INDICES

scores = pd.read_csv(SCORES_FILE)
expected_rows = 2 * 12 * 10 * 4
if len(scores) != expected_rows:
    raise ValueError(f"Expected {expected_rows} score rows, found {len(scores)}.")

subject_scores = (
    scores.groupby(
        ["Condition", "Cohort", "StoredSubjectIndex", "Participant", "Phase"],
        as_index=False,
    )["Silhouette"].mean()
)


def significance_label(p_value):
    return "*" if p_value < 0.05 else "NS"


def add_comparison(ax, x1, x2, y, label, height=0.045):
    ax.plot([x1, x1, x2, x2], [y, y + height, y + height, y],
            color="black", lw=1.1)
    ax.text((x1 + x2) / 2, y + height + 0.008, label,
            ha="center", va="bottom", fontsize=10)


positions = {"Low MEQ": np.arange(1, 5), "High MEQ": np.arange(6, 10)}
rng = np.random.default_rng(20261005)
fig, axes = plt.subplots(1, 2, figsize=(13.5, 4.8), sharey=True)
statistics = []

for panel, (ax, condition) in enumerate(zip(axes, CONDITIONS)):
    condition_data = subject_scores[subject_scores["Condition"].eq(condition)]
    plotted, colors, all_positions = [], [], []
    for cohort in ["Low MEQ", "High MEQ"]:
        for phase, position in zip(PHASES, positions[cohort]):
            values = condition_data[
                condition_data["Cohort"].eq(cohort)
                & condition_data["Phase"].eq(phase)
            ]["Silhouette"].to_numpy()
            plotted.append(values)
            colors.append(PHASE_COLORS[phase])
            all_positions.append(position)

    boxes = ax.boxplot(
        plotted, positions=all_positions, widths=0.58, patch_artist=True,
        medianprops={"color": "#555555"}, whiskerprops={"color": "#555555"},
        capprops={"color": "#555555"},
    )
    for box, color in zip(boxes["boxes"], colors):
        box.set(facecolor=color, edgecolor="black", linewidth=1.0)
    for position, values in zip(all_positions, plotted):
        ax.scatter(position + rng.normal(0, 0.035, size=len(values)), values,
                   color="grey", alpha=0.75, s=18, zorder=3)

    for phase_index, phase in enumerate(PHASES):
        low = condition_data[
            condition_data["Cohort"].eq("Low MEQ")
            & condition_data["Phase"].eq(phase)
        ]["Silhouette"].to_numpy()
        high = condition_data[
            condition_data["Cohort"].eq("High MEQ")
            & condition_data["Phase"].eq(phase)
        ]["Silhouette"].to_numpy()
        test = ttest_ind(low, high, equal_var=False)
        statistics.append({
            "Condition": condition, "Phase": phase.capitalize(),
            "LowMean": low.mean(), "HighMean": high.mean(),
            "WelchT": test.statistic, "PValue": test.pvalue,
        })
        add_comparison(
            ax, positions["Low MEQ"][phase_index],
            positions["High MEQ"][phase_index],
            1.03 + phase_index * 0.12, significance_label(test.pvalue),
        )

    ax.set_title(condition, fontsize=13)
    ax.set_xticks([2.5, 7.5], ["Low MEQ", "High MEQ"])
    ax.set_ylim(-0.5, 1.58)
    ax.set_ylabel("Silhouette score" if panel == 0 else "")
    ax.text(-0.13, 1.03, "c" if panel == 0 else "d", transform=ax.transAxes,
            fontsize=16, fontweight="bold")

legend = [Line2D([0], [0], color=PHASE_COLORS[p], lw=7, label=label)
          for p, label in zip(PHASES, PHASE_LABELS)]
fig.legend(handles=legend, frameon=False, ncol=4, loc="lower center",
           bbox_to_anchor=(0.5, -0.02))
fig.tight_layout(rect=(0, 0.08, 1, 1))
fig.savefig(OUTPUT / "figure_silhouette_low_high_meq.png", dpi=300,
            bbox_inches="tight")
plt.close(fig)
pd.DataFrame(statistics).to_csv(
    OUTPUT / "silhouette_group_statistics.csv", index=False
)


def median_absolute_deviation(values):
    values = np.asarray(values, dtype=float)
    median = np.median(values)
    return float(np.median(np.abs(values - median)))


psilocybin_scores = scores[scores["Condition"].eq("Psilocybin")].copy()
phase_stability = (
    psilocybin_scores.groupby(["StoredSubjectIndex", "Participant", "Phase"])
    ["Silhouette"]
    .agg(SD=lambda x: np.std(x, ddof=1), MAD=median_absolute_deviation)
    .reset_index()
)
participant_stability = (
    phase_stability.groupby(["StoredSubjectIndex", "Participant"])[["SD", "MAD"]]
    .mean().reset_index().set_index("StoredSubjectIndex")
    .reindex(STABILITY_ORDER).reset_index()
)
participant_stability["ParticipantLabel"] = [f"P{i}" for i in range(1, 13)]
participant_stability.to_csv(OUTPUT / "silhouette_run_stability.csv", index=False)

fig, axes = plt.subplots(1, 2, figsize=(13.5, 3.6), sharey=True)
for ax, (column, ylabel, panel) in zip(
    axes, [("SD", "s.d.", "e"), ("MAD", "MAD", "f")]
):
    x = np.arange(12)
    ax.bar(x, participant_stability[column], width=0.78, color="#1f77b4")
    ax.set_xticks(x, participant_stability["ParticipantLabel"])
    ax.set_ylim(0, 1.0)
    ax.set_ylabel(ylabel)
    ax.text(-0.13, 1.03, panel, transform=ax.transAxes,
            fontsize=16, fontweight="bold")

fig.tight_layout(w_pad=3.5)
fig.savefig(OUTPUT / "figure_silhouette_run_stability.png", dpi=300,
            bbox_inches="tight")
plt.close(fig)

print(f"Saved fresh Fig. 3c-d and Fig. 3e-f outputs to {OUTPUT}")

