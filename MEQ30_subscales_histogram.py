# Import necessary libraries
import os
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import pandas as pd

# output directory and file name
dir_out = './figures'
f_out = 'MEQ_histogram'
os.makedirs(dir_out, exist_ok=True)

# Root of the scored phenotype folder
dir_phenotype = '/path/to/PsiConnect/derivatives/phenotype/scored'

# Load MEQ30 scored data
data = pd.read_csv(os.path.join(dir_phenotype, 'ses-02/MEQ30.tsv'), sep='\t')

# Define the MEQ columns to include, explicitly excluding "MEQ30_MEAN" and including "MEQ30_TRANSCEND"
meq_columns_filtered = [col for col in data.columns if "MEQ" in col and col != "MEQ30_MEAN"]

x_axis_limit = 100
y_axis_limit_meq = 43  # Y-axis max for MEQ histograms

# Define bins with width of 20 for thicker bars
bins = np.arange(0, 101, 20)

# Helper function to clean up column names for display
def clean_column_name_extended(column_name):
    return column_name.replace("MEQ30_", "")

# Create a grid layout for MEQ histograms only
fig = plt.figure(figsize=(6, 6))

# Plot each MEQ category with y-axis limit of 33
plot_index = 1
for i in range(len(meq_columns_filtered)):
    ax = fig.add_subplot(2, 2, plot_index)  # One row layout for MEQ
    
    column = meq_columns_filtered[i]
    
    # Plot the histogram
    sns.histplot(data[column].dropna(), color="#4A90E2", ax=ax, bins=bins)
    
    ax.set_xlim(0, x_axis_limit)
    ax.set_ylabel('')
    ax.set_xlabel(clean_column_name_extended(column), fontsize=12)
    
    plot_index += 1

plt.tight_layout()
plt.savefig(f'{dir_out}/{f_out}.png', dpi=400)
plt.savefig(f'{dir_out}/{f_out}.pdf')
plt.show()
