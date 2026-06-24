# Import necessary libraries
import os
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import pandas as pd

# output directory and file name
dir_out = './figures'
f_out = 'ASC11_histograms'
os.makedirs(dir_out, exist_ok=True)

# Root of the scored phenotype folder
dir_phenotype = '/path/to/PsiConnect/derivatives/phenotype/scored'

# Load ASC11 scored data
data = pd.read_csv(os.path.join(dir_phenotype, 'ses-02/ASC11.tsv'), sep='\t')

# Define the categories in the desired order for the 11D ASC
dasc_order_reordered = [
    'ASC11_UNITY', 'ASC11_BLISSFUL', 'ASC11_SPIRITUAL', 'ASC11_INSIGHTFUL',  # First row (4 histograms)
    'ASC11_ELEMENTARY', 'ASC11_COMPLEX', 'ASC11_AUDIOVISUAL',                # Second row (3 histograms)
    'ASC11_ANXIETY', 'ASC11_COGNITION',                                       # Third row (2 histograms)
    'ASC11_DISEMBODY', 'ASC11_PERCEPTS'                                       # Fourth row (2 histograms)
]

# Exact color values for each 11D ASC category as per previous visualizations
color_mapping_final_adjusted = {
    'ASC11_UNITY': "#4A90E2",       # Blue for Unity
    'ASC11_BLISSFUL': "#4A90E2",
    'ASC11_SPIRITUAL': "#4A90E2",
    'ASC11_INSIGHTFUL': "#4A90E2",
    'ASC11_ELEMENTARY': "#E57E3A",  # Orange for Elementary
    'ASC11_COMPLEX': "#E57E3A",
    'ASC11_AUDIOVISUAL': "#E57E3A",
    'ASC11_ANXIETY': "#D9534F",     # Red for Anxiety
    'ASC11_COGNITION': "#D9534F",
    'ASC11_DISEMBODY': "#B1A7E0",   # Purple for Disembody
    'ASC11_PERCEPTS': "#B1A7E0"     
}

# Plot configuration with y-axis limit options for 11D ASC histograms
x_axis_limit = 100
y_axis_limit_asc = 33  # Y-axis max for 11D ASC histograms

# Helper function to clean up column names for display
def clean_column_name_extended(column_name):
    return column_name.replace("ASC11_", "")

# Define bins with width of 20 for thicker bars
bins = np.arange(0, 101, 20)

# Create a grid layout for 11D ASC histograms
fig = plt.figure(figsize=(8, 8))

# Define the row layout for the 11D ASC histograms
row_layout_asc = [4, 3, 2, 2]  # Layout corresponds to 4 rows with specified columns

# Plot each 11D ASC category according to the layout
plot_index = 1
for row_num, cols_in_row in enumerate(row_layout_asc):
    for i in range(cols_in_row):
        ax = fig.add_subplot(4, 4, plot_index)
        
        column = dasc_order_reordered[plot_index - 1]  # 11D ASC columns only
        color = color_mapping_final_adjusted.get(column, "gray")
        
        # Plot the histogram
        sns.histplot(data[column].dropna(), color=color, ax=ax, bins=bins)
        
        # Set title and enforce square aspect ratio
        ax.set_xlim(0, x_axis_limit)
        ax.set_ylim(0, y_axis_limit_asc)
        ax.set_yticks(range(0, y_axis_limit_asc, 5))
        ax.set_ylabel('')
        ax.set_xlabel(clean_column_name_extended(column),fontsize=12)
        
        plot_index += 1

# Hide any unused subplots to maintain the 4x4 layout
for ax in fig.axes[plot_index - 1:]:  # Hide remaining subplots after plotting
    fig.delaxes(ax)

plt.tight_layout()
plt.savefig(f'{dir_out}/{f_out}.png', dpi=400)
plt.savefig(f'{dir_out}/{f_out}.pdf')
plt.show()