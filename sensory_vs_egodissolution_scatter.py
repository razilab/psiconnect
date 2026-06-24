import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

# output directory and file name
dir_out = './figures'
f_out = 'scatter_sensory_vs_ego'
os.makedirs(dir_out, exist_ok=True)

# Root of the scored phenotype folder
dir_phenotype = '/path/to/PsiConnect/derivatives/phenotype/scored'

# Load ASC11 scored data
admin_day_data = pd.read_csv(os.path.join(dir_phenotype, 'ses-02/ASC11.tsv'), sep='\t')

# Filtering necessary columns and merging on 'participant_id'
# Selecting MEDEQ scores and ASC scores along with participant_id

x_axis_columns = ['ASC11_SPIRITUAL', 'ASC11_UNITY', 'ASC11_BLISSFUL']
x_average = admin_day_data[x_axis_columns].copy()
x_average['average'] = x_average.mean(axis=1)
y_axis_columns = ['ASC11_COMPLEX', 'ASC11_ELEMENTARY']
y_average = admin_day_data[y_axis_columns].copy()
y_average['average'] = y_average.mean(axis=1)

x_average.head()
y_average.head()


# Plotting the bar chart
plt.figure(figsize=(4, 4))
sns.set_style("whitegrid")
sns.scatterplot(
    x=x_average['average'], 
    y=y_average['average']
)
# Adding plot details
plt.xlabel('Ego dissolution scores', fontsize=12)
plt.ylabel('Sensory scores', fontsize=12)
# identity line for reference (dashed grey)
plt.plot([0, 100], [0, 100], '--', color='grey')

# Adjusting the padding
plt.subplots_adjust(left=0.15,right=0.95)

plt.savefig(f'{dir_out}/{f_out}_corr.png', dpi=400)
plt.savefig(f'{dir_out}/{f_out}_corr.pdf')
plt.show()