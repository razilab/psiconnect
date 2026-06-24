# ============================================================
# Required Libraries
# ============================================================

import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
from scipy.stats import pearsonr


# ============================================================
# User options
# ============================================================

# Significance threshold for adding one asterisk
ALPHA = 0.05

# Small visual correction because the asterisk glyph often appears slightly high
# Make this more negative if the star still looks too high
STAR_Y_NUDGE_POINTS = -2.5

# Horizontal distance between the bar end and the asterisk, in points
STAR_X_OFFSET_POINTS = 5

# Output directory and file name
dir_out = './figures'
f_out = 'mindset_vs_admin_corr'

# Root of the scored phenotype folder
dir_phenotype = '/path/to/PsiConnect/derivatives/phenotype/scored'

# Input files
mindset_file = os.path.join(dir_phenotype, 'followup-1day/MINDSET.tsv')
asc11_file   = os.path.join(dir_phenotype, 'ses-02/ASC11.tsv')
meq30_file   = os.path.join(dir_phenotype, 'ses-02/MEQ30.tsv')

# Rename labels for plotting only
DISPLAY_LABEL_RENAME = {
    'COGNITION': 'IMPAIRED'
}


# ============================================================
# Prepare output directory
# ============================================================

os.makedirs(dir_out, exist_ok=True)


# ============================================================
# Load the participant mindset averages
# ============================================================

mindset_averages = pd.read_csv(mindset_file, sep='\t')

# Keep only columns that start with MINDSET
mindset_columns = [
    col for col in mindset_averages.columns
    if col.startswith("MINDSET")
]

# Ensure all mindset columns are numeric
mindset_averages[mindset_columns] = mindset_averages[mindset_columns].apply(
    pd.to_numeric,
    errors='coerce'
)

# Create new column by taking the mean of all mindset columns
mindset_averages["Mindset_Average_Score"] = mindset_averages[mindset_columns].mean(
    axis=1,
    skipna=True
)

# Only keep participant_id and Mindset_Average_Score
merged_data = mindset_averages[["participant_id", "Mindset_Average_Score"]]

# Display the first few rows to verify
print(merged_data.head())


# ============================================================
# Load the experience scores: ASC11
# ============================================================

dasc_data = pd.read_csv(asc11_file, sep='\t')

# Select ASC columns
dasc_columns = ["participant_id"] + [
    col for col in dasc_data.columns
    if col.startswith("ASC")
]

print("ASC columns:")
print(dasc_columns)

# Merge mindset averages with ASC data on participant_id
merged_data = pd.merge(
    merged_data,
    dasc_data[dasc_columns],
    on='participant_id'
)


# ============================================================
# Load the experience scores: MEQ30
# ============================================================

meq_data = pd.read_csv(meq30_file, sep='\t')

# Select MEQ30 columns
meq30_columns = ["participant_id"] + [
    col for col in meq_data.columns
    if col.startswith("MEQ30")
]

print("MEQ30 columns:")
print(meq30_columns)

# Merge MEQ30 data with existing merged data
merged_data = pd.merge(
    merged_data,
    meq_data[meq30_columns],
    on='participant_id'
)


# ============================================================
# Prepare columns for correlation
# ============================================================

# Drop participant_id before correlation
merged_data = merged_data.drop(columns=['participant_id'])

# Convert all remaining columns to numeric
merged_data = merged_data.apply(pd.to_numeric, errors='coerce')

# Correlate mindset with ASC and MEQ30 columns only
correlation_columns = [
    col for col in list(dasc_columns) + list(meq30_columns)
    if col != "participant_id"
]

print("Correlation columns:")
print(correlation_columns)


# ============================================================
# Compute correlations and p-values
# ============================================================

correlations = []

for col in correlation_columns:
    if col in merged_data.columns:
        valid_data = merged_data[['Mindset_Average_Score', col]].dropna()

        # pearsonr needs enough observations and non-constant data
        if (
            len(valid_data) >= 3
            and valid_data['Mindset_Average_Score'].nunique() > 1
            and valid_data[col].nunique() > 1
        ):
            corr, p_val = pearsonr(
                valid_data['Mindset_Average_Score'],
                valid_data[col]
            )

            correlations.append((col, corr, p_val, len(valid_data)))
        else:
            print(f"Skipping {col}: not enough valid data or constant values.")


# Convert to DataFrame
correlation_plot_data = pd.DataFrame(
    correlations,
    columns=['Variable', 'Correlation', 'P-value', 'N']
)


# ============================================================
# Filter variables
# ============================================================

# Keep only MEQ30_ and ASC11_ variables
# Exclude MEQ30_MEAN and COMPOSITE variables
correlation_plot_data = correlation_plot_data[
    correlation_plot_data['Variable'].str.startswith(('MEQ30_', 'ASC11_')) &
    (correlation_plot_data['Variable'] != 'MEQ30_MEAN') &
    ~(correlation_plot_data['Variable'].str.contains('COMPOSITE', na=False))
].copy()


# ============================================================
# Clean and rename variable names for plotting
# ============================================================

# Remove prefixes from variable names
correlation_plot_data['Variable'] = correlation_plot_data['Variable'].str.replace(
    'MEQ30_',
    '',
    regex=True
)

correlation_plot_data['Variable'] = correlation_plot_data['Variable'].str.replace(
    'ASC11_',
    '',
    regex=True
)

# Rename COGNITION to IMPAIRED for display only
correlation_plot_data['Variable'] = correlation_plot_data['Variable'].replace(
    DISPLAY_LABEL_RENAME
)

# Sort by correlation
correlation_plot_data = correlation_plot_data.sort_values(
    by='Correlation',
    ascending=False
).reset_index(drop=True)

print("Final plotting data:")
print(correlation_plot_data)


# ============================================================
# Define color mapping
# ============================================================

soft_color_mapping = {

    'UNITY': "#4A90E2",
    'BLISSFUL': "#4A90E2",
    'SPIRITUAL': "#4A90E2",
    'INSIGHTFUL': "#4A90E2",

    'ELEMENTARY': "#E57E3A",
    'COMPLEX': "#E57E3A",
    'AUDIOVISUAL': "#E57E3A",

    'ANXIETY': "#D9534F",
    'COGNITION': "#D9534F",
    'IMPAIRED': "#D9534F",

    'DISEMBODY': "#B1A7E0",
    'PERCEPTS': "#B1A7E0",

    'MYSTICAL': "#4A90E2",
    'POSITIVE': "#4A90E2",
    'TRANSCEND': "#4A90E2",
    'INEFFABILITY': "#4A90E2"
}

# Add a default grey colour for any variables not listed above
for variable in correlation_plot_data['Variable'].unique():
    if variable not in soft_color_mapping:
        soft_color_mapping[variable] = "#BBBBBB"


# ============================================================
# Plotting
# ============================================================

plt.figure(figsize=(6, 4))

ax = sns.barplot(
    x='Correlation',
    y='Variable',
    hue='Variable',
    data=correlation_plot_data,
    palette=soft_color_mapping,
    saturation=0.75,
    legend=False
)

ax.set_title('Correlation with mindset change', fontsize=12)
plt.xlabel('', fontsize=12)
plt.ylabel('', fontsize=12)

# Optional reference line at zero
# plt.axvline(x=0, color='grey', lw=1)


# ============================================================
# Add a single visually centred asterisk for significance
# ============================================================

for bar, (_, row) in zip(ax.patches, correlation_plot_data.iterrows()):
    p_val = row['P-value']
    correlation = row['Correlation']

    if pd.notna(p_val) and p_val < ALPHA:
        width = bar.get_width()
        y = bar.get_y() + bar.get_height() / 2

        if correlation >= 0:
            x_offset = STAR_X_OFFSET_POINTS
            ha = "left"
        else:
            x_offset = -STAR_X_OFFSET_POINTS
            ha = "right"

        ax.annotate(
            "*",
            xy=(width, y),
            xytext=(x_offset, STAR_Y_NUDGE_POINTS),
            textcoords="offset points",
            va="center",
            ha=ha,
            fontsize=14,
            fontweight="bold",
            color="black",
            annotation_clip=False
        )


# ============================================================
# Expand x-axis limits so asterisks are not clipped
# ============================================================

x_min, x_max = ax.get_xlim()
x_range = x_max - x_min

ax.set_xlim(
    x_min - 0.05 * x_range,
    x_max + 0.05 * x_range
)


# ============================================================
# Adjust layout and save
# ============================================================

plt.subplots_adjust(left=0.3)

plt.savefig(f'{dir_out}/{f_out}.png', dpi=400, bbox_inches='tight')
plt.savefig(f'{dir_out}/{f_out}.pdf', bbox_inches='tight')

plt.show()