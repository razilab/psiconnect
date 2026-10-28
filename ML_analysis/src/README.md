# Fresh CEBRA, repeated-fit silhouette, and network-perturbation workflows

This directory contains optional from-scratch reproduction
workflows; it is not an archive of the exact historical execution that created the published embeddings. The workflows use the recording-wise config in
`data/cebra_config.csv` together with the original time-series data stored at
`../data/psicon_time_series.pkl`. They are separate from the main paper-results
notebook, which uses the exact saved embeddings used for the reported figures.


## Full fresh psilocybin run

`fresh_cebra_training.ipynb` is the primary readable workflow, with
`fresh_cebra_training.py` providing the same analysis as a script. Every
execution trains all 54 psilocybin CEBRA models from scratch; it does not load cached embeddings.

The workflow:

1. reads the psilocybin configuration for each participant;
2. loads and concatenates rest, meditation, music, and movie recordings;
3. fixes the participant-specific random seed;
4. trains CEBRA through the selected checkpoint sequence;
5. exports the newly generated three-dimensional embeddings;
6. refits the classifier for each participant;
7. calculates the classification-accuracy–MEQ association; and
8. creates the correlation figure and trajectory animations.

Run the notebook interactively, or run the matching script from the repository
root:

```bash
python src/fresh_cebra_training.py
```

New embeddings, tables, figures, and GIFs are written to `src/fresh_cebra_outputs/`. The
combined fresh-run embedding file is
`src/fresh_cebra_outputs/fresh_psilocybin_cebra_embeddings.pkl`; it is a stochastic
reproduction output and does not replace the published embeddings in `data/`.

### Configuration

`data/cebra_config.csv` contains one row for every participant and session.
Each row records the batch size, staged-training schedule checkpoint,
corresponding effective optimizer-update count, and learning rate. The
no-psilocybin and psilocybin recordings are treated as
separate training samples and therefore have separate configurations.

The environment is specified by the repository-level `requirements.txt` and uses Python 3.10. Fresh CEBRA optimization remains stochastic even when the software versions and random seeds are fixed, so newly generated embeddings and downstream statistics may slightly differ from the published results. Across 10 fresh-reproduction runs done by the authors, the Psilocybin classification-accuracy–MEQ30 correlation was (r = 0.60 ± 0.03 ) (mean ± s.d).

## Fresh network-perturbation run

The network analysis is implemented by `run_network_perturbation.py` and
`plot_network_attribution.py`. The perturbation seed offset is fixed at `100000`, matching the retained reference checkpoints and outputs.

The workflow is:

1. trains a fresh no-psilocybin CEBRA model;
2. trains a fresh psilocybin CEBRA model;
3. transforms the original psilocybin recording;
4. replaces each of eight networks with its length-matched no-psilocybin trajectory and transforms it with the same fitted psilocybin model;
5. refits the fixed one-vs-rest classifier on every embedding; and
6. saves the original and perturbed accuracies in the same format consumed by the plotting code.

Run:

```bash
python src/run_network_perturbation.py
python src/plot_network_attribution.py
```

Example outputs and participant-level embedding checkpoints from fresh runs are retained under
`src/network_perturbation_outputs/`. Running the workflow always trains fresh CEBRA models and overwrites these example files; the plotting script reads the newly generated accuracy table from the same directory. Within a participant, one fitted psilocybin model is shared across the original trajectory and all eight network replacements; CEBRA is not retrained separately for each network.


The regenerated perturbation values are not expected to be numerically identical to the published values because of underlying CEBRA stochasticity. Participant order,
model configuration, checkpoint sequence, classifier, ROI-to-network assignments, and replacement operations are fixed to reduce avoidable variation.

## Fresh repeated-fit silhouette run

`run_repeated_fit_silhouette.py` reproduces the full computational path for Fig. 3c--f using fresh CEBRA fits.
Participants are displayed in increasing MEQ order within each set of 'low accuracy' and 'high accuracy' groups. The script separately processes No psilocybin and Psilocybin recordings and performs 10 independently seeded fresh fits for every participant and session. Each fit uses that recording's configuration from `data/cebra_config.csv`.

For every fit, the complete three-dimensional embedding is saved before cosine silhouette coefficients are calculated for rest, meditation, music, and movie.
The plotting script then calculates participant means, statistical tests, across-fit standard deviations, and median absolute deviations directly from the fresh fit-level scores.

Run:

```bash
python src/run_repeated_fit_silhouette.py
python src/plot_repeated_fit_silhouette.py
```

A fresh example of per-fit embeddings, a combined embedding bundle, score tables,
statistics, and the two figures are retained under
`src/silhouette_repeated_fit_outputs/`. Running the workflow always performs 240 fresh CEBRA fits and overwrites these example files; the plotting script reads the newly generated score table from the same directory. The seed family is fixed and recorded in every checkpoint. As with the other fresh workflows, these results may have slight numerical differences from the historical published panels because each CEBRA model is newly trained.


## TL;DR — CEBRA model configuration

CEBRA hyperparameters and training duration were selected **independently for each participant and session** (No psilocybin and Psilocybin), using a systematic, training-loss-based optimization procedure. Selection was guided by loss convergence and stability, not by correlations with any of the behavioural measures. Once the configurations were determined, the resulting three-dimensional embeddings were saved and used for downstream condition classification and behavioural correlation analyses.

### Additional technical details: CEBRA model configuration 

CEBRA exposes several optimization and model hyperparameters, and the geometry of a learned representation can depend appreciably on their specification. We therefore performed model selection separately for every recording, treating each No psilocybin recording and each Psilocybin recording as an independent trajectory. The embedding dimensionality was fixed at 3 throughout. The model architecture (`offset10-model`), cosine distance, time-conditional training, temperature (1.12), and time offset (10) were held fixed so that the search focused principally on learning rate, batch size, and training duration.

The principal search space included learning rates of **$1 \times 10^{-4}$, $2 \times 10^{-4}$, $3 \times 10^{-4}$, $1 \times 10^{-3}$, $2 \times 10^{-3}$, and $3 \times 10^{-3}$**, batch sizes of **32, 64, 128, 256, and 512**, and staged-training schedule checkpoints of **10, 20, 100, 200, 500, 1,000, 2,000, 5,000, and 10,000**. The search was organized in stages to make the full recording-wise analysis computationally tractable. Candidate learning-rate and batch-size combinations were initially assessed over the earlier training checkpoints. Configurations that retained favourable optimization behaviour were subsequently evaluated at longer training durations, where appropriate. This preserved broad coverage of the parameter space while avoiding unnecessary extension of configurations whose loss trajectories were already uncompetitive or unstable.

To support staged evaluation, checkpointing and resumable training, CEBRA models were advanced incrementally using `partial_fit`. The `schedule_checkpoint` column records the predefined stage reached by this procedure. Because the initialized CEBRA data loader retains its original 20-update length across successive `partial_fit` calls, these schedule checkpoints are not literal optimizer-update counts. The corresponding number of recorded optimization updates is provided separately in `effective_updates`.

The supplied workflows use the incremental schedule to preserve checkpoint-level evaluation and recovery. For an uninterrupted fit, `effective_updates` can instead be supplied as `max_iterations` in a single `CEBRA.fit` call. This gives the corresponding optimization length and preserves the same optimizer trajectory when initialization and sampled batches are identical. As with any separate CEBRA execution, numerically identical embeddings are not guaranteed because model initialization and data sampling remain stochastic.

Selection was guided primarily by the CEBRA training-loss trajectory. Training could be continued incrementally on the same fitted model, with loss evaluated at predefined checkpoints. To reduce sensitivity to individual mini-batch fluctuations, checkpoint-level behaviour was summarized using the mean of the final ten recorded loss values, while the corresponding standard deviation provided a local stability diagnostic. Relative improvement between adjacent smoothed-loss windows was calculated as

```math
\text{relative improvement}
=
\frac{\text{previous mean loss} - \text{recent mean loss}}
{\max\left(\left|\text{previous mean loss}\right|,\varepsilon\right)}
```

where $\varepsilon$ prevents numerical instability when the denominator is close to zero. The earliest schedule checkpoint eligible for stopping was 20. A relative improvement below approximately **1.5%** provided evidence that a trajectory was approaching a loss plateau. This criterion was considered together with the attained loss, the magnitude and persistence of subsequent improvement, variability within the terminal loss window, and the behaviour of competing configurations. Earlier checkpoints were preferred when convergence was sufficiently supported, whereas training was extended when loss continued to decrease materially or remained locally unstable. Schedule checkpoint 10,000 provided a common upper bound. Accordingly, the effective training duration could differ between recordings while remaining governed by the same loss-based selection framework.

The selection criteria were evaluated jointly rather than as an exhaustive sequence of independent hard-threshold decisions. Supporting diagnostic checks were used to distinguish configurations with similar loss behaviour, examine non-monotonic trajectories, and confirm the stability of a candidate selection. These checks complemented the central loss-based rationale and allowed ambiguous cases to be assessed within the same general framework.

The sweep was checkpointed and resumable because it comprised 108 independent recording trajectories and required substantial computation. Random-number generators were initialized with recorded participant- and session-specific seeds, and deterministic Torch algorithms were requested where supported. After parameter selection, the retained settings were saved and CEBRA was run once for each recording. The resulting three-dimensional embeddings were then exported for the downstream analyses. The participant- and session-specific configurations used by the fresh reproduction workflows are recorded in `src/data/cebra_config.csv`.

CEBRA training uses stochastic optimization. Fixing seeds, software versions, device type, and deterministic-computation settings substantially improves reproducibility, but numerically identical embeddings are not guaranteed across hardware, library versions, repeated runs, or execution environments. For a new time-series dataset, we recommend repeating the recording-wise parameter search and convergence assessment before final CEBRA training.
