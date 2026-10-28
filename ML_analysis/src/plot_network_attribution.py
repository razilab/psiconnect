"""Plot network-attribution panels from regenerated perturbation accuracies.

Run this after ``run_network_perturbation.py``. No CEBRA fitting occurs here.
"""

from pathlib import Path
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
from matplotlib.patches import Patch
import numpy as np
import pandas as pd


SRC = Path.cwd()
if SRC.name != "src" and (SRC / "src").exists():
    SRC = SRC / "src"
OUTPUT = SRC / "network_perturbation_outputs"
INPUT = OUTPUT / "network_perturbation_accuracies.csv"

network_data = pd.read_csv(INPUT)
network_columns = ["Sub", "Vis", "SomMot", "DorsAttn", "Limbic",
                   "SalVentAttn", "Default", "Cont"]
perturbed_columns = [f"{network}PerturbedAccuracy" for network in network_columns]
required = ["ParticipantLabel", "StoredSubjectIndex", "NoPsilocybinAccuracy",
            "PsilocybinAccuracy"] + perturbed_columns
if network_data.columns.tolist() != required:
    raise ValueError(f"Unexpected columns in {INPUT}.")
if len(network_data) != 6:
    raise ValueError("Expected six participants.")

no_psilocybin_accuracy = network_data["NoPsilocybinAccuracy"].to_numpy(dtype=float)
psilocybin_accuracy = network_data["PsilocybinAccuracy"].to_numpy(dtype=float)
perturbed_accuracy = network_data[perturbed_columns].to_numpy(dtype=float)
drops = (psilocybin_accuracy[:, None] - perturbed_accuracy) * 100
gain = psilocybin_accuracy - no_psilocybin_accuracy

positive_drops = np.clip(drops, 0, None)
weights = np.divide(
    positive_drops,
    positive_drops.sum(axis=1, keepdims=True),
    out=np.zeros_like(positive_drops),
    where=positive_drops.sum(axis=1, keepdims=True) > 0,
)
contribution = weights * gain[:, None]
participant_percent = weights * 100

no_psilocybin_mean = float(no_psilocybin_accuracy.mean())
psilocybin_mean = float(psilocybin_accuracy.mean())
gain_mean = psilocybin_mean - no_psilocybin_mean
if np.isclose(gain_mean, 0):
    raise ValueError("Mean accuracy gain is zero; attribution is undefined.")
contribution_mean = contribution.mean(axis=0)
mean_profile = contribution_mean / gain_mean

network_labels = ["Sub", "Vis", "Somnot", "Dorsattn", "Limbic",
                  "Salventattn", "Default", "Cont"]
network_colors = ["#377eb8", "#ff7f00", "#4daf4a", "#e41a1c",
                  "#00cccc", "#a65628", "#f781bf", "#333333"]

with plt.rc_context({
    "font.family": "sans-serif", "font.sans-serif": ["DejaVu Sans"],
    "font.size": 10, "axes.labelsize": 11, "xtick.labelsize": 9,
    "ytick.labelsize": 9, "axes.linewidth": 1.0,
}):
    fig = plt.figure(figsize=(15.5, 4.8))
    grid = GridSpec(1, 3, figure=fig, width_ratios=[1.15, 1.05, 1.75], wspace=0.38)

    ax_g = fig.add_subplot(grid[0, 0], projection="polar")
    angles = np.linspace(0, 2 * np.pi, len(network_columns), endpoint=False)
    closed_angles = np.r_[angles, angles[0]]
    closed_values = np.r_[mean_profile, mean_profile[0]]
    ax_g.plot(closed_angles, closed_values, color="#4c4c4c", lw=1.5)
    ax_g.fill(closed_angles, closed_values, color="#8d79c6", alpha=0.30)
    for angle, value, color in zip(angles, mean_profile, network_colors):
        ax_g.scatter(angle, value, s=34, color=color, zorder=3)
    ax_g.set_xticks(angles)
    ax_g.set_xticklabels(network_labels)
    radial_max = max(0.24, float(np.nanmax(mean_profile)) * 1.18)
    ax_g.set_ylim(0, radial_max)
    ax_g.grid(alpha=0.35)
    ax_g.text(-0.16, 1.12, "g", transform=ax_g.transAxes,
              fontsize=17, fontweight="bold")

    ax_h = fig.add_subplot(grid[0, 1])
    order = np.argsort(contribution_mean)
    waterfall_labels = ["No psilocybin"] + [network_labels[i] for i in order] + ["Psilocybin"]
    xx = np.arange(len(waterfall_labels))
    ax_h.bar(xx[0], no_psilocybin_mean, width=0.88, color="#9a9a9a",
             edgecolor="#666666", linewidth=0.8)
    running = no_psilocybin_mean
    for position, network_index in enumerate(order, start=1):
        value = contribution_mean[network_index]
        ax_h.bar(position, value, bottom=running, width=0.88,
                 color=network_colors[network_index], alpha=0.70,
                 edgecolor="#666666", linewidth=0.6)
        ax_h.plot([position - 1 + 0.44, position - 0.44], [running, running],
                  color="#777777", lw=0.8)
        ax_h.text(position, running + value + 0.012,
                  f"{100 * value / gain_mean:+.1f}%",
                  ha="center", va="bottom", fontsize=8)
        running += value
    ax_h.bar(xx[-1], psilocybin_mean, width=0.88, color="#9a9a9a",
             edgecolor="#666666", linewidth=0.8)
    ax_h.axhline(no_psilocybin_mean, color="#777777", ls="--", lw=1, alpha=0.65)
    ax_h.axhline(psilocybin_mean, color="#777777", ls="--", lw=1, alpha=0.65)
    ax_h.set_xticks(xx)
    ax_h.set_xticklabels(waterfall_labels, rotation=52, ha="right")
    ax_h.set_ylabel("Accuracy")
    ax_h.set_ylim(0, 1.05)
    ax_h.spines[["top", "right"]].set_visible(False)
    ax_h.text(-0.20, 1.05, "h", transform=ax_h.transAxes,
              fontsize=17, fontweight="bold")

    ax_i = fig.add_subplot(grid[0, 2])
    x = np.arange(len(network_data))
    for participant_index in range(len(network_data)):
        bottom = 0.0
        for network_index in np.argsort(participant_percent[participant_index]):
            value = participant_percent[participant_index, network_index]
            if value <= 0:
                continue
            ax_i.bar(x[participant_index], value, bottom=bottom, width=0.78,
                     color=network_colors[network_index], alpha=0.70,
                     edgecolor="#666666", linewidth=0.5)
            bottom += value
    ax_i.set_xticks(x)
    ax_i.set_xticklabels(network_data["ParticipantLabel"])
    ax_i.set_ylabel("Contribution to gain (%)")
    ax_i.set_ylim(0, 100)
    ax_i.spines[["top", "right"]].set_visible(False)
    handles = [Patch(facecolor=color, edgecolor="#666666", alpha=0.70,
                     label=label)
               for label, color in zip(network_labels, network_colors)]
    ax_i.legend(handles=handles, frameon=False, ncol=6,
                loc="lower center", bbox_to_anchor=(0.5, 1.02),
                fontsize=8, columnspacing=0.9, handlelength=0.8,
                handletextpad=0.3)
    ax_i.text(-0.14, 1.05, "i", transform=ax_i.transAxes,
              fontsize=17, fontweight="bold")

    fig.subplots_adjust(left=0.055, right=0.995, bottom=0.22, top=0.82)
    figure_path = OUTPUT / "figure_network_attribution_g_h_i.png"
    fig.savefig(figure_path, dpi=300, bbox_inches="tight")
    plt.show()

summary = pd.DataFrame({
    "Network": network_labels,
    "MeanContribution": contribution_mean,
    "PercentOfMeanGain": mean_profile * 100,
})
summary.to_csv(OUTPUT / "network_attribution_summary.csv", index=False)

with np.load(OUTPUT / "network_perturbation_confusion_matrices.npz") as saved:
    reference_recall = np.diagonal(saved["psilocybin_reference"], axis1=-2, axis2=-1)
    substituted_recall = np.diagonal(saved["network_substituted"], axis1=-2, axis2=-1)
    mean_delta_recall = (reference_recall[:, None, :] - substituted_recall).mean(axis=0)
    phase_names = saved["phase_names"].astype(str)

fig, ax = plt.subplots(figsize=(5.2, 5.8))
image = ax.imshow(mean_delta_recall, cmap="bwr", vmin=0,
                  vmax=float(np.max(np.abs(mean_delta_recall))))
ax.set_xticks(range(4), phase_names, rotation=45, ha="right")
ax.set_yticks(range(8), network_labels)
ax.set(xlabel="Condition", ylabel="Network",
       title="Across subjects: mean Δ recall")
for row in range(8):
    for column in range(4):
        ax.text(column, row, f"{mean_delta_recall[row, column]:+.2f}",
                ha="center", va="center", fontsize=9)
fig.colorbar(image, ax=ax)
fig.tight_layout()
heatmap_path = OUTPUT / "figure_network_condition_recall_heatmap.png"
fig.savefig(heatmap_path, dpi=300, bbox_inches="tight")
plt.show()
print(summary.to_string(index=False))
print(f"Saved {figure_path}")
print(f"Saved {heatmap_path}")

