# PsiConnect analysis code

Code used to preprocess, clean, and analyse **PsiConnect**, a multi-echo fMRI dataset of context-dependent, psilocybin-induced changes in brain connectivity and behaviour. 

The dataset is publicly available on [OpenNeuro](https://openneuro.org/datasets/ds006110), and the code can be used to reproduce the results reported in:

- Stoliker, D. et al. (2025). Psychedelics Align Brain Activity with Context. [https://doi.org/10.1101/2025.03.09.642197](https://doi.org/10.1101/2025.03.09.642197)

- Novelli, L. et al. (2026). PsiConnect: Multimodal Neuroimaging of Context-Dependent Brain and Behaviour Dynamics under Psilocybin. Sci Data. [https://doi.org/10.1038/s41597-026-07312-1](https://doi.org/10.1038/s41597-026-07312-1).

---


## Prerequisites

| Software | Version used | Notes |
|---|---|---|
| MATLAB | R2024b | |
| [SPM12](https://www.fil.ion.ucl.ac.uk/spm/) | r7771 | Add to MATLAB path |
| [bids-matlab](https://github.com/bids-standard/bids-matlab) | 0.1.0 | Add to MATLAB path |
| [Brain Connectivity Toolbox](https://sites.google.com/site/bctnet/) | 2022.12.08 | Required for `modularity()` in `FC_diff_matrix.m` |
| [BrainEigenmodes](https://github.com/james-pang/BrainEigenmodes) | 2024.06.11 | Required for surface plotting and colormaps |
| Singularity | 3.7.1 | HPC only — for fMRIPrep, MRIQC, Tedana containers |
| [tedana](https://tedana.readthedocs.io/en/stable/index.html) | 0.0.12 | For ME-ICA |
| FSL | 6.0.7 | HPC only — required by `ROI_time_series_extraction_single.m` |
| Python | 3.12.2 | Required for behavioural plotting scripts; packages: `pandas`, `matplotlib`, `seaborn`, `scipy`, `scikit-learn` |

Shell scripts (`.sh`) are written for **SLURM** job arrays on an HPC cluster. Before submitting, edit the `#SBATCH --account` and `#SBATCH --mail-user` fields in each script.

---

## Getting started

1. Clone this repository and add it to your MATLAB path.
2. Download the PsiConnect dataset from [OpenNeuro](https://openneuro.org/datasets/ds006110).
3. Open any script and follow the `USER-CONFIGURABLE SETTINGS` block at the top (at minimum set `dir_base` to the root folder of the PsiConnect dataset).

---

## Script overview

### Quality Control

| Script | Description |
|---|---|
| `mriqc_singularity.sh` | SLURM job array: runs [MRIQC v22.0.6](https://mriqc.readthedocs.io/) per participant via Singularity |
| `mriqc_PCA.m` | Loads the MRIQC group TSV; PCA and plots of QC metrics and framewise displacement |

### Preprocessing

| Script | Description |
|---|---|
| `fmriprep_singularity.sh` | SLURM job array: runs [fMRIPrep v22.0.2](https://fmriprep.org/) per participant via Singularity |

### Cleaning

| Script | Description |
|---|---|
| `tedana.sh` | SLURM job array: runs [Tedana v0.0.12](https://tedana.readthedocs.io/) (ME-ICA component classification), then registers outputs to MNI space |
| `glm_tedana_cleaning.m` | SPM12 GLM confound regression: motion parameters, CSF, WM, and Tedana-rejected ICA components. Optionally also regresses the global signal |

### ROI Time Series Extraction

Assumes ROI masks (individual NIFTI files per ROI) are available under `derivatives/parcellations/`.

| Script | Description |
|---|---|
| `ROI_time_series_extraction.sh` | SLURM job array: runs `ROI_time_series_extraction_single.m` per participant |
| `ROI_time_series_extraction_single.m` | Reslices ROI masks to BOLD space, extracts the first principal component of each ROI; saves to `derivatives/timeseries/` |

### Functional Connectivity (FC) and Global FC (GFC)

| Script | Description |
|---|---|
| `FC_diff_matrix.m` | Loads ROI time series, computes FC matrices, modularity |
| `volume_to_surface_single_run.m` | Projects cleaned BOLD volumes (MNI space) onto the fsLR-32k cortical surface — prerequisite for the scripts below |
| `FC_diff_corticalsurface.m` | Loads fsLR-32k surface GFC; computes and plots psilocybin-minus-baseline GFC differences on cortical surface |
| `FC_diff_corticalsurface_histograms4tasks.m` | GFC histograms and boxplots per Schaefer network, across tasks and sessions |

### Spectral DCM — Individual Level

| Script | Description |
|---|---|
| `spDCM.sh` | SLURM job array: runs `spDCM_single_run.m` per participant |
| `spDCM_single_run.m` | Fits a spectral DCM (cross-spectral density) model to ROI time series for a single run using SPM12 |

### Behavioural Measures Plotting

All scripts read scored phenotype TSV files from `derivatives/phenotype/scored/`. Set `dir_phenotype` at the top of each script before running.

| Script | Description |
|---|---|
| `ASC11_subscales_histogram.py` | Histograms of all 11 ASC11 (altered states of consciousness) subscale scores |
| `MEQ30_subscales_histogram.py` | Histograms of MEQ30 (mystical experience questionnaire) subscale scores |
| `experience_intensity_histogram.py` | Histogram of subjective psilocybin experience intensity ratings |
| `sensory_vs_egodissolution_scatter.py` | Scatter plot of sensory experience scores vs ego dissolution scores (ASC11 subscales) |
| `ASC11_subgroups_correlation_heatmap.py` | Pearson correlation heatmaps of ASC11 subscales across participant subgroups |
| `MEDEQ_vs_experience_regression.py` | Linear regression and R² of MEDEQ (meditation experience) predicting ASC11 and MEQ30 scores |
| `MINDSET_vs_experience_corr.py` | Bar chart of Pearson correlations between MINDSET (1-day follow-up) and psilocybin experience scores |

### Helper Functions

| Script | Description |
|---|---|
| `bids_filenames_to_table.m` | Parses BIDS-format filenames into a MATLAB table with one row per file |
| `add_behav.m` | Joins behavioural scores from `participants.tsv` and `phenotype/` TSV files onto a data table |
| `match_subjects_across_groups.m` | Keeps only subjects present in all groups/sessions (inner join) |
| `exclude_from_table.m` | Removes rows corresponding to an exclusion list |
| `plot_surface_fsLR_32k.m` | Plots a data vector on the fsLR-32k cortical surface mesh |
