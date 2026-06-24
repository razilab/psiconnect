# ============================================================
# Import necessary libraries
# ============================================================

import os
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
from scipy.stats import pearsonr


# ============================================================
# User options
# ============================================================

# Turn Bonferroni correction on or off
USE_BONFERRONI = False

# Significance threshold
ALPHA = 0.05

# font
FONT_SIZE_HEATMAP = 16
FONT_SIZE_LABELS = 12.5

# Output directory and file name
dir_out = './figures'
f_out = 'ASC11_subgroups_corr'
os.makedirs(dir_out, exist_ok=True)

# Root of the scored phenotype folder
dir_phenotype = '/path/to/PsiConnect/derivatives/phenotype/scored'

# Input file
data_file = os.path.join(dir_phenotype, 'ses-02/ASC11.tsv')

# Rename labels for display in plots only
# The original data column is still expected to be ASC11_COGNITION
DISPLAY_LABEL_RENAME = {
    "COGNITION": "IMPAIRED"
}


# ============================================================
# Helper functions
# ============================================================

def get_display_labels(labels):
    """
    Convert original variable labels to plot display labels.
    For example, COGNITION becomes IMPAIRED.
    """
    return [DISPLAY_LABEL_RENAME.get(label, label) for label in labels]


def load_group_data(data, labels):
    """
    Select ASC11 columns for one group, remove the ASC11_ prefix,
    and rename labels for display in plots.

    Important:
    The labels argument should contain the original data names, for example:
    COGNITION, not IMPAIRED.
    """
    columns = [f"ASC11_{label}" for label in labels]

    missing_columns = [col for col in columns if col not in data.columns]

    if missing_columns:
        raise ValueError(
            "The following columns are missing from the data file: "
            + ", ".join(missing_columns)
        )

    group_data = data[columns].copy()

    # Remove ASC11_ prefix
    group_data = group_data.rename(columns=lambda x: x.replace("ASC11_", ""))

    # Rename labels for display in plots
    group_data = group_data.rename(columns=DISPLAY_LABEL_RENAME)

    # Convert values to numeric
    for col in group_data.columns:
        group_data[col] = pd.to_numeric(group_data[col], errors="coerce")

    return group_data


def compute_corr_and_pvalues(group_data):
    """
    Compute Pearson correlation coefficients, p-values, and pairwise sample sizes.

    The sample size can differ between pairs if there are missing values.
    """
    corr = group_data.corr(method="pearson")

    cols = group_data.columns

    pvals = pd.DataFrame(
        np.nan,
        index=cols,
        columns=cols
    )

    nvals = pd.DataFrame(
        np.nan,
        index=cols,
        columns=cols
    )

    for i in range(len(cols)):
        for j in range(len(cols)):
            x = group_data.iloc[:, i]
            y = group_data.iloc[:, j]

            valid = x.notna() & y.notna()
            x_valid = x[valid]
            y_valid = y[valid]

            nvals.iloc[i, j] = len(x_valid)

            if i == j:
                pvals.iloc[i, j] = np.nan
            else:
                if len(x_valid) >= 3 and x_valid.nunique() > 1 and y_valid.nunique() > 1:
                    _, p = pearsonr(x_valid, y_valid)
                    pvals.iloc[i, j] = p
                else:
                    pvals.iloc[i, j] = np.nan

    return corr, pvals, nvals


def count_unique_tests(group_corrs):
    """
    Count the number of unique off-diagonal correlations across all plotted groups.

    This is used for Bonferroni correction.
    The diagonal is not counted because it is always 1.00.
    """
    unique_pairs = set()

    for corr in group_corrs:
        cols = list(corr.columns)

        for i in range(len(cols)):
            for j in range(i + 1, len(cols)):
                pair = tuple(sorted([cols[i], cols[j]]))
                unique_pairs.add(pair)

    return len(unique_pairs)


def make_correlation_annotations(corr, pvals, alpha_threshold):
    """
    Create annotation labels for the heatmap.

    Significant correlations receive one star only.
    Non-significant correlations receive no star.
    """
    annot = pd.DataFrame(
        "",
        index=corr.index,
        columns=corr.columns
    )

    for i in range(corr.shape[0]):
        for j in range(corr.shape[1]):
            r = corr.iloc[i, j]
            p = pvals.iloc[i, j]

            if pd.isna(r):
                annot.iloc[i, j] = ""
            elif i == j:
                annot.iloc[i, j] = f"{r:.2f}"
            else:
                star = "*" if pd.notna(p) and p < alpha_threshold else ""
                annot.iloc[i, j] = f"{r:.2f}{star}"

    return annot


def check_for_negative_correlations(group_corrs):
    """
    Check whether any off-diagonal correlations are negative.

    If negative correlations exist, print a warning because the current colour bar
    uses vmin=0 and vmax=1.
    """
    negative_values = []

    for group_name, corr in group_corrs.items():
        cols = list(corr.columns)

        for i in range(len(cols)):
            for j in range(i + 1, len(cols)):
                r = corr.iloc[i, j]

                if pd.notna(r) and r < 0:
                    negative_values.append((group_name, cols[i], cols[j], r))

    if negative_values:
        print("")
        print("WARNING: At least one negative correlation was found.")
        print("The current colour bar uses vmin=0 and vmax=1.")
        print("If negative correlations are present, the colour bar should be changed.")
        print("Recommended change: use vmin=-1, vmax=1 and a diverging colour map.")
        print("")
        print("Negative correlations found:")

        for group_name, var_1, var_2, r in negative_values:
            print(f"{group_name}: {var_1} vs {var_2}, r = {r:.3f}")

        print("")


def plot_group_heatmap(
    fig,
    subplot_position,
    corr,
    annot,
    labels,
    cmap,
    diagonal_colors,
    cbar=True
):
    """
    Plot one correlation heatmap.
    """
    ax = fig.add_subplot(2, 2, subplot_position)

    sns.heatmap(
        corr,
        annot=annot,
        cbar=cbar,
        cmap=cmap,
        fmt="",
        vmin=0,
        vmax=1,
        ax=ax,
        annot_kws={"size": FONT_SIZE_HEATMAP}
    )

    # Increase font size of labels outside the matrix
    ax.set_xticklabels(
        ax.get_xticklabels(),
        fontsize=FONT_SIZE_LABELS,
        rotation=0,
    )

    ax.set_yticklabels(
        ax.get_yticklabels(),
        fontsize=FONT_SIZE_LABELS,
        rotation=90
    )

    # Optional: increase tick label font size more generally
    ax.tick_params(axis="both", labelsize=FONT_SIZE_LABELS)

    # Colour the diagonal cells
    for i, label in enumerate(labels):
        ax.add_patch(
            plt.Rectangle(
                (i, i),
                1,
                1,
                fill=True,
                color=diagonal_colors[label]
            )
        )

        # Re-add the diagonal text because the rectangle patch covers the original annotation
        ax.text(
            i + 0.5,
            i + 0.5,
            "1.00",
            ha="center",
            va="center",
            color="white",
            fontsize=FONT_SIZE_HEATMAP
        )

    return ax


def print_sample_sizes(group_nvals):
    """
    Print the pairwise sample sizes used for each ASC11 correlation matrix.
    """
    print("")
    print("Sample sizes used for ASC11 correlation matrices")
    print("Note: values are pairwise Ns, so they can differ if data are missing.")
    print("")

    for group_name, nvals in group_nvals.items():
        print(f"{group_name}:")
        print(nvals.astype("Int64"))
        print("")

        off_diagonal_ns = []

        for i in range(nvals.shape[0]):
            for j in range(i + 1, nvals.shape[1]):
                n = nvals.iloc[i, j]
                if pd.notna(n):
                    off_diagonal_ns.append(int(n))

        if off_diagonal_ns:
            unique_ns = sorted(set(off_diagonal_ns))

            if len(unique_ns) == 1:
                print(f"{group_name} off-diagonal correlations all used N = {unique_ns[0]}")
            else:
                print(f"{group_name} off-diagonal correlations used Ns = {unique_ns}")

        print("-" * 60)
        print("")


# ============================================================
# Load data
# ============================================================

os.makedirs(dir_out, exist_ok=True)

data = pd.read_csv(data_file, sep='\t')


# ============================================================
# Define groups using original data labels
# ============================================================

group_1_labels = ['UNITY', 'BLISSFUL', 'SPIRITUAL']
group_2_labels = ['ELEMENTARY', 'COMPLEX', 'AUDIOVISUAL']
group_3_labels = ['ANXIETY', 'COGNITION']
group_4_labels = ['COGNITION', 'SPIRITUAL']


# ============================================================
# Define display labels for plotting
# ============================================================

group_1_plot_labels = get_display_labels(group_1_labels)
group_2_plot_labels = get_display_labels(group_2_labels)
group_3_plot_labels = get_display_labels(group_3_labels)
group_4_plot_labels = get_display_labels(group_4_labels)


# ============================================================
# Prepare group data
# ============================================================

group_1_data = load_group_data(data, group_1_labels)
group_2_data = load_group_data(data, group_2_labels)
group_3_data = load_group_data(data, group_3_labels)
group_4_data = load_group_data(data, group_4_labels)


# ============================================================
# Calculate correlations and p-values
# ============================================================

dasc_group_1_correlation, dasc_group_1_pvalues, dasc_group_1_nvals = compute_corr_and_pvalues(group_1_data)
dasc_group_2_correlation, dasc_group_2_pvalues, dasc_group_2_nvals = compute_corr_and_pvalues(group_2_data)
dasc_group_3_correlation, dasc_group_3_pvalues, dasc_group_3_nvals = compute_corr_and_pvalues(group_3_data)
dasc_group_4_correlation, dasc_group_4_pvalues, dasc_group_4_nvals = compute_corr_and_pvalues(group_4_data)

all_group_corrs = {
    "Group 1": dasc_group_1_correlation,
    "Group 2": dasc_group_2_correlation,
    "Group 3": dasc_group_3_correlation,
    "Group 4": dasc_group_4_correlation
}

all_group_nvals = {
    "Group 1": dasc_group_1_nvals,
    "Group 2": dasc_group_2_nvals,
    "Group 3": dasc_group_3_nvals,
    "Group 4": dasc_group_4_nvals
}

print_sample_sizes(all_group_nvals)

check_for_negative_correlations(all_group_corrs)


# ============================================================
# Apply optional Bonferroni correction
# ============================================================

n_tests = count_unique_tests(
    [
        dasc_group_1_correlation,
        dasc_group_2_correlation,
        dasc_group_3_correlation,
        dasc_group_4_correlation
    ]
)

if USE_BONFERRONI:
    alpha_threshold = ALPHA / n_tests
    print("Bonferroni correction is ON.")
    print(f"Number of unique tests: {n_tests}")
    print(f"Corrected alpha threshold: {alpha_threshold:.6f}")
else:
    alpha_threshold = ALPHA
    print("Bonferroni correction is OFF.")
    print(f"Uncorrected alpha threshold: {alpha_threshold:.6f}")


# ============================================================
# Create annotation matrices
# ============================================================

dasc_group_1_annot = make_correlation_annotations(
    dasc_group_1_correlation,
    dasc_group_1_pvalues,
    alpha_threshold
)

dasc_group_2_annot = make_correlation_annotations(
    dasc_group_2_correlation,
    dasc_group_2_pvalues,
    alpha_threshold
)

dasc_group_3_annot = make_correlation_annotations(
    dasc_group_3_correlation,
    dasc_group_3_pvalues,
    alpha_threshold
)

dasc_group_4_annot = make_correlation_annotations(
    dasc_group_4_correlation,
    dasc_group_4_pvalues,
    alpha_threshold
)


# ============================================================
# Colours
# ============================================================

color_mapping_final_adjusted = {
    'UNITY': "#4A90E2",
    'BLISSFUL': "#4A90E2",
    'SPIRITUAL': "#4A90E2",

    'ELEMENTARY': "#E57E3A",
    'COMPLEX': "#E57E3A",
    'AUDIOVISUAL': "#E57E3A",

    'ANXIETY': "#D9534F",

    # Original data label and display label are both included for safety
    'COGNITION': "#D9534F",
    'IMPAIRED': "#D9534F",

    'DISEMBODY': "#B1A7E0",
    'PERCEPTS': "#B1A7E0"
}

group_4_diagonal_color = "grey"

group_4_diagonal_colors = {
    'IMPAIRED': group_4_diagonal_color,
    'SPIRITUAL': group_4_diagonal_color
}

group_1_cmap = sns.light_palette(color_mapping_final_adjusted['UNITY'], as_cmap=True)
group_2_cmap = sns.light_palette(color_mapping_final_adjusted['ELEMENTARY'], as_cmap=True)
group_3_cmap = sns.light_palette(color_mapping_final_adjusted['ANXIETY'], as_cmap=True)
group_4_cmap = sns.light_palette("grey", as_cmap=True)


# ============================================================
# Plot heatmaps
# ============================================================

fig = plt.figure(figsize=(9, 8))

# Group 1
plot_group_heatmap(
    fig=fig,
    subplot_position=1,
    corr=dasc_group_1_correlation,
    annot=dasc_group_1_annot,
    labels=group_1_plot_labels,
    cmap=group_1_cmap,
    diagonal_colors=color_mapping_final_adjusted
)

# Group 2
plot_group_heatmap(
    fig=fig,
    subplot_position=3,
    corr=dasc_group_2_correlation,
    annot=dasc_group_2_annot,
    labels=group_2_plot_labels,
    cmap=group_2_cmap,
    diagonal_colors=color_mapping_final_adjusted
)

# Group 3
# COGNITION is displayed as IMPAIRED
plot_group_heatmap(
    fig=fig,
    subplot_position=2,
    corr=dasc_group_3_correlation,
    annot=dasc_group_3_annot,
    labels=group_3_plot_labels,
    cmap=group_3_cmap,
    diagonal_colors=color_mapping_final_adjusted
)

# Group 4
# COGNITION is displayed as IMPAIRED
plot_group_heatmap(
    fig=fig,
    subplot_position=4,
    corr=dasc_group_4_correlation,
    annot=dasc_group_4_annot,
    labels=group_4_plot_labels,
    cmap=group_4_cmap,
    diagonal_colors=group_4_diagonal_colors
)


# ============================================================
# Save and show figure
# ============================================================

plt.tight_layout()

plt.savefig(f'{dir_out}/{f_out}.png', dpi=400)
plt.savefig(f'{dir_out}/{f_out}.pdf')

plt.show()