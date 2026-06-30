# PsiConnect analysis code

Code used to preprocess, clean, and analyse **PsiConnect**, a multi-echo fMRI dataset of context-dependent, psilocybin-induced changes in brain connectivity and behaviour.

The dataset is publicly available on https://openneuro.org/datasets/ds006110.

This repository can be used to reproduce the results reported in:

- Stoliker, D. et al. (2025). *Psychedelics Align Brain Activity with Context*.  
  https://doi.org/10.1101/2025.03.09.642197

- Novelli, L. et al. (2026). *PsiConnect: Multimodal Neuroimaging of Context-Dependent Brain and Behaviour Dynamics under Psilocybin*. *Scientific Data*.  
  https://doi.org/10.1038/s41597-026-07312-1

---

## Quick start

1. Clone this repository and add it to your MATLAB path.
2. Download the PsiConnect dataset from https://openneuro.org/datasets/ds006110.
3. Open the script you want to run.
4. Edit the `USER-CONFIGURABLE SETTINGS` block at the top of the script (at minimum, set `dir_base` to the root folder of the PsiConnect dataset).

---

## Prerequisites

### Core software

| Software | Version used |
|:---|:---|
| MATLAB | R2024b |
| [SPM12](https://www.fil.ion.ucl.ac.uk/spm/) | r7771 |
| [bids-matlab](https://github.com/bids-standard/bids-matlab) | 0.1.0 |
| [Brain Connectivity Toolbox](https://sites.google.com/site/bctnet/) | 2022.12.08 |
| [BrainEigenmodes](https://github.com/james-pang/BrainEigenmodes) | 2024.06.11 |
| [EEGLAB](https://sccn.ucsd.edu/eeglab/index.php) | 2021.0 |
| [FieldTrip](https://www.fieldtriptoolbox.org/) | 20240916 |
| Singularity | 3.7.1 |
| [tedana](https://tedana.readthedocs.io/en/stable/index.html) | 0.0.12 |
| FSL | 6.0.7 |
| Python | 3.12.2 |

### Dependency notes

- **Brain Connectivity Toolbox** is required for `modularity()` in `FC_diff_matrix.m`.
- **BrainEigenmodes** is required for surface plotting and colormaps.
- **EEGLAB** and **FieldTrip** are required for EEG analysis and plotting.
- **Singularity** is only needed on HPC systems for fMRIPrep, MRIQC, and Tedana containers.
- **FSL** is only needed for `ROI_time_series_extraction_single.m`.
- **Python** is required for behavioural plotting scripts.

Required Python packages:

- `pandas`
- `matplotlib`
- `seaborn`
- `scipy`
- `scikit-learn`

---

## Repository workflow

The analysis pipeline is organised into the following broad stages:

- Quality control
- Preprocessing
- Cleaning
- ROI time series extraction
- Functional connectivity analysis
- Surface-based global functional connectivity analysis
- Spectral DCM
- EEG analysis
- Behavioural measures plotting
- Helper functions

Each stage is described below:


### Quality control

- `mriqc_singularity.sh`  
  SLURM job array that runs [MRIQC](https://mriqc.readthedocs.io/) for each participant via Singularity.

- `mriqc_PCA.m`  
  Loads the MRIQC group TSV file, performs PCA, and plots quality control metrics and framewise displacement.

---

### Preprocessing

- `fmriprep_singularity.sh`  
  SLURM job array that runs [fMRIPrep](https://fmriprep.org/) for each participant via Singularity.

---

### Cleaning

- `tedana.sh`  
  SLURM job array that runs [tedana](https://tedana.readthedocs.io/) for ME-ICA component classification, then registers outputs to MNI space.

- `glm_tedana_cleaning.m`  
  Runs SPM12 GLM confound regression using motion parameters, CSF, white matter, and Tedana-rejected ICA components. Optionally also regresses the global signal.

---

### ROI time series extraction

This stage assumes that ROI masks are available as individual NIFTI files under `derivatives/parcellations/`

- `ROI_time_series_extraction.sh`  
  SLURM job array that runs `ROI_time_series_extraction_single.m` for each participant.

- `ROI_time_series_extraction_single.m`  
  Reslices ROI masks to BOLD space, extracts the first principal component of each ROI, and saves the output to `derivatives/timeseries/`

---

### Functional connectivity and global functional connectivity

- `FC_diff_matrix.m`  
  Loads ROI time series, computes functional connectivity matrices, and calculates modularity.

- `volume_to_surface_single_run.m`  
  Projects cleaned BOLD volumes in MNI space onto the fsLR-32k cortical surface. This is a prerequisite for the cortical surface scripts below.

- `FC_diff_corticalsurface.m`  
  Loads fsLR-32k surface global functional connectivity data, computes psilocybin-minus-baseline GFC differences, and plots results on the cortical surface.

- `FC_diff_corticalsurface_histograms4tasks.m`  
  Generates GFC histograms and boxplots per Schaefer network across tasks and sessions.

---

### Spectral DCM: individual level

- `spDCM.sh`  
  SLURM job array that runs `spDCM_single_run.m` for each participant.

- `spDCM_single_run.m`  
  Fits a spectral DCM model to ROI time series for a single run using SPM12.

---

### EEG analysis

- `eeg_compute_spectrum.m`  
  Computes power spectrum via Fast Fourier Transform (FFT).
- `eeg_CSD_2D_to_3D.m`  
  Reshapes 2D cross-spectral density vectors into 3D tensors (Channels x Channels x Frequencies).
- `eeg_plots.m`  
  Plots power spectra across frequency ranges (Theta, Alpha, Beta, Gamma), and Lempel-Ziv complexity.

---

### Behavioural measures plotting

All behavioural plotting scripts read scored phenotype TSV files from `derivatives/phenotype/scored/`

Before running these scripts, set `dir_phenotype` at the top of each script.

- `ASC11_subscales_histogram.py`  
  Plots histograms of all 11 ASC11 altered states of consciousness subscale scores.

- `MEQ30_subscales_histogram.py`  
  Plots histograms of MEQ30 mystical experience questionnaire subscale scores.

- `experience_intensity_histogram.py`  
  Plots a histogram of subjective psilocybin experience intensity ratings.

- `ASC11_subgroups_correlation_heatmap.py`  
  Plots Pearson correlation heatmaps of ASC11 subscales across participant subgroups.

---

### Helper functions

- `bids_filenames_to_table.m`  
  Parses BIDS-format filenames into a MATLAB table with one row per file.

- `add_behav.m`  
  Joins behavioural scores from `participants.tsv` and phenotype TSV files onto a data table.

- `match_subjects_across_groups.m`  
  Keeps only subjects present in all groups and sessions using an inner join.

- `exclude_from_table.m`  
  Removes rows corresponding to an exclusion list.

- `plot_surface_fsLR_32k.m`  
  Plots a data vector on the fsLR-32k cortical surface mesh.

- `LZ_complexity_1976.m`  
  Calculates Lempel-Ziv algorithmic complexity.

---

## Expected directory structure

The scripts assume a BIDS-style PsiConnect dataset with derivative folders organised approximately as follows:

```text
PsiConnect/
├── bids/
│   ├── participants.tsv
│   ├── sub-PC001/
│   ├── sub-PC002/
│   └── ...
├── derivatives/
│   ├── fmriprep/
│   ├── mriqc/
│   ├── tedana/
│   ├── parcellations/
│   ├── timeseries/
│   ├── spDCM/
│   ├── EEG/
│   └── phenotype/
└── ...
```

Exact paths should be checked and edited in the `USER-CONFIGURABLE SETTINGS` block at the top of each script.

---

## HPC usage notes

The shell scripts in this repository are designed for SLURM job arrays. Before submitting jobs, check the following settings:

- SLURM account name
- Email address
- Requested wall time
- Requested memory
- Number of CPUs
- Singularity image paths
- Input and output directories

At minimum, update:

```bash
#SBATCH --account=your_account
#SBATCH --mail-user=your_email@example.com
```

The scripts may need minor edits depending on the configuration of your local HPC cluster.

---

## Citation

If you use this code or dataset, please cite the associated dataset and analysis papers:

Stoliker, D. et al. (2025). *Psychedelics Align Brain Activity with Context*.  
https://doi.org/10.1101/2025.03.09.642197

Novelli, L. et al. (2026). *PsiConnect: Multimodal Neuroimaging of Context-Dependent Brain and Behaviour Dynamics under Psilocybin*. *Scientific Data*.  
https://doi.org/10.1038/s41597-026-07312-1