import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.linear_model import LinearRegression
from sklearn.metrics import r2_score, mean_squared_error
import numpy as np
from scipy.stats import pearsonr

# output directory and file name
dir_out = './figures'
f_out = 'MEDEQ'
os.makedirs(dir_out, exist_ok=True)

# Root of the scored phenotype folder
dir_phenotype = '/path/to/PsiConnect/derivatives/phenotype/scored'

# Load baseline (MEDEQ) and administration-day questionnaire data
baseline_data  = pd.read_csv(os.path.join(dir_phenotype, 'ses-01/MEDEQ.tsv'), sep='\t')
asc11_data     = pd.read_csv(os.path.join(dir_phenotype, 'ses-02/ASC11.tsv'), sep='\t')
meq30_data     = pd.read_csv(os.path.join(dir_phenotype, 'ses-02/MEQ30.tsv'), sep='\t')
admin_day_data = pd.merge(asc11_data, meq30_data, on='participant_id', how='inner')

# Baseline (MEDEQ) relevant columns
baseline_columns = ['participant_id', 'MEDEQ_HINDER', 'MEDEQ_RELAX', 'MEDEQ_CONCENTRATE', 'MEDEQ_QUALTIES', 
                    'MEDEQ_NONDUAL', 'MEDEQ_TOTAL']
baseline_filtered = baseline_data[baseline_columns]

# Merging datasets on participant_id
merged_data = pd.merge(baseline_filtered, admin_day_data, on='participant_id', how='inner')

# Dropping rows with missing values in the relevant MEDEQ and ASC columns
merged_data_clean = merged_data.dropna()

# Checking the cleaned data structure for regression analysis
merged_data_clean.head()



# Prepare data for regression analysis
results = []

# Define predictor variables (MEDEQ scores) and outcome variables (ASC scores)
predictors = ['MEDEQ_HINDER', 'MEDEQ_RELAX', 'MEDEQ_CONCENTRATE', 'MEDEQ_QUALTIES', 'MEDEQ_NONDUAL', 'MEDEQ_TOTAL']

# Extending outcome variables to include all ASC11* and MEQ30* columns
outcomes = [col for col in admin_day_data.columns if col.startswith('ASC11_')] + [col for col in admin_day_data.columns if col.startswith('MEQ30_')]

# Filter to keep only MEQ30_ and ASC11_ variables, excluding MEQ30_MEAN and COMPOSITE
outcomes = [col for col in outcomes if 
           (col.startswith(('MEQ30_', 'ASC11_'))) and 
           (col != 'MEQ30_MEAN') and 
           ('COMPOSITE' not in col)]

# remove the prefix from the variable names
outcomes = [col.replace('MEQ30_', '').replace('ASC11_', '') for col in outcomes]

# Filtering merged data with updated outcomes columns

# remove the prefix from the column names
admin_day_data.columns = admin_day_data.columns.str.replace('MEQ30_', '')
admin_day_data.columns = admin_day_data.columns.str.replace('ASC11_', '')
admin_day_filtered = admin_day_data[['participant_id'] + outcomes]

# merge
merged_data = pd.merge(baseline_filtered, admin_day_filtered, on='participant_id', how='inner')
merged_data_clean = merged_data.dropna()
merged_data_clean.head()

# Performing regression analysis again with expanded outcomes
results = []

for outcome in outcomes:
    X = merged_data_clean[predictors]
    y = merged_data_clean[outcome]
    
    # Fit the linear regression model
    model = LinearRegression()
    model.fit(X, y)
    y_pred = model.predict(X)
    
    # Calculate performance metrics
    r2 = r2_score(y, y_pred)
    coefficients = model.coef_
    intercept = model.intercept_
    correlation = np.corrcoef(y, y_pred)[0, 1]
    
    # Store the results
    results.append({
        'Outcome_Variable': outcome,
        'Intercept': intercept,
        'R2': r2,
        'Correlation': correlation,
        **dict(zip(predictors, coefficients))
    })

# Converting results to DataFrame
results_df = pd.DataFrame(results)
results_df.head()

# Define the custom color scheme for each outcome
custom_palette = {
    'UNITY': "#8ABAD4",
    'BLISSFUL': "#8ABAD4",
    'SPIRITUAL': "#8ABAD4",
    'INSIGHTFUL': "#8ABAD4",
    'ELEMENTARY': "#F5A97F",
    'COMPLEX': "#F5A97F",
    'AUDIOVISUAL': "#F5A97F",
    'ANXIETY': "#F5A5A5",
    'COGNITION': "#F5A5A5",
    'DISEMBODY': "#C8B7E8",
    'PERCEPTS': "#C8B7E8",
    'MYSTICAL': "#8ABAD4",
    'POSITIVE': "#8ABAD4",
    'TRANSCEND': "#8ABAD4",
    'INEFFABILITY': "#8ABAD4"
}

# Extracting only the necessary columns for MEDEQ_TOTAL correlations and sorting in descending order
meq_total_correlations = results_df[['Outcome_Variable', 'MEDEQ_TOTAL', 'Correlation']].sort_values(by='Correlation', ascending=False)
filtered_colors = [custom_palette.get(outcome, "#D3D3D3") for outcome in meq_total_correlations['Outcome_Variable']]

# Plotting the bar chart
plt.figure(figsize=(6, 4))
#sns.set_style("whitegrid")
sns.barplot(
    x=meq_total_correlations['Correlation'], 
    y=meq_total_correlations['Outcome_Variable'], 
    palette=filtered_colors
)
# Adding plot details
#plt.title('Correlation between MEDEQ_TOTAL and ASC/MEQ Scores', fontsize=16)
plt.xlabel('Correlation with MEDEQ scores', fontsize=12)
plt.ylabel('', fontsize=12)
plt.axvline(x=0, color='grey', linestyle='--')

plt.subplots_adjust(left=0.3)

plt.savefig(f'{dir_out}/{f_out}_corr.png', dpi=400)
plt.savefig(f'{dir_out}/{f_out}_corr.pdf')
plt.show()




# Extracting only the necessary columns for MEDEQ_TOTAL correlations and sorting in descending order
meq_R2 = results_df[['Outcome_Variable', 'MEDEQ_TOTAL', 'R2']].sort_values(by='R2', ascending=False)
filtered_colors = [custom_palette.get(outcome, "#D3D3D3") for outcome in meq_R2['Outcome_Variable']]

# Plotting the R2 values as a horizontal bar plot in descending order
plt.figure(figsize=(6,4))
#sns.set_style("whitegrid")
sns.barplot(
    x=meq_R2['R2'], 
    y=meq_R2['Outcome_Variable'], 
    palette=filtered_colors
)
plt.xlabel('R^2 for MEDEQ Predicting DASC/MEQ Scores', fontsize=12)
plt.ylabel('', fontsize=12)
plt.tight_layout()
plt.savefig(f'{dir_out}/{f_out}_R2.png', dpi=400)
plt.savefig(f'{dir_out}/{f_out}_R2.pdf')
plt.show()



# Adding p-values for correlation significance
significance_results = []
for index, row in meq_total_correlations.iterrows():
    outcome_variable = row['Outcome_Variable']
    correlation_value = row['Correlation']
    
    # Calculate p-value for the correlation
    X = merged_data_clean[['MEDEQ_TOTAL']]
    y = merged_data_clean[outcome_variable]
    
    # Compute Pearson correlation and p-value
    corr, p_value = pearsonr(X.squeeze(), y)
    
    # Store results
    significance_results.append({
        'Outcome_Variable': outcome_variable,
        'Correlation': correlation_value,
        'P_Value': p_value,
        'R2': meq_R2.loc[meq_R2['Outcome_Variable'] == outcome_variable, 'R2'].values[0]
    })

# Convert results to DataFrame for review and display to user
significance_df = pd.DataFrame(significance_results)
significance_df.head()

