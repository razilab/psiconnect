# Required Libraries
import os
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import pandas as pd

# output directory and file name
dir_out = './figures'
f_out = 'intensity_histogram'
os.makedirs(dir_out, exist_ok=True)

# Root of the scored phenotype folder
dir_phenotype = '/path/to/PsiConnect/derivatives/phenotype/scored'

# Load intensity experience data
# Note: update the filename below to match the actual scored file in the phenotype folder
intensity = pd.read_csv(os.path.join(dir_phenotype, 'followup-1day/INTENSITY.tsv'), sep='\t')
# Keep only columns that start with "INTENSITY_"
intensity_columns = [col for col in intensity.columns if col.startswith("INTENSITY_")]
intensity = intensity[intensity_columns]
# Ensure all mindset columns are numeric
intensity = intensity.apply(pd.to_numeric, errors='coerce')
# remove nans
intensity = intensity.dropna()
# Display the first few rows to verify
print(intensity.head())
intensity = intensity.values.flatten()

# Define bins with width of 20 for thicker bars
bins = np.arange(0.5, 11.5, 1)

# Create a grid layout for MEQ histograms only
fig = plt.figure(figsize=(4, 4))
ax = fig.add_subplot(1, 1, 1)

# Plot the histogram
sns.histplot(intensity, color="#4A90E2", ax=ax, bins=bins)

ax.set_xlim(0.5, 10.5)
ax.set_ylim(0, 21)
ax.set_xticks(range(1, 11, 1))
ax.set_yticks(range(0, 22, 3))
ax.set_ylabel('')
ax.set_xlabel('Intensity of experience', fontsize=12)

ax.legend().set_visible(False)

plt.savefig(f'{dir_out}/{f_out}.png', dpi=400)
plt.savefig(f'{dir_out}/{f_out}.pdf')
plt.show()
