"""Regenerate network-perturbation accuracies from frozen CEBRA parameters.

This is a computational reproduction pipeline, not the source of the exact
published numbers. It trains fresh CEBRA models and therefore may produce
different numerical results because CEBRA optimization is stochastic.

Run from ``src`` or its parent directory with::

    python src/run_network_perturbation.py

The script checkpoints every participant immediately. Every invocation trains
all CEBRA models from scratch and overwrites the retained example outputs.
"""

from pathlib import Path
import os
import pickle
import random

import numpy as np
import pandas as pd
import torch
from cebra import CEBRA
from sklearn.base import clone
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, confusion_matrix
from sklearn.multiclass import OneVsRestClassifier


SRC = Path.cwd()
if SRC.name != "src" and (SRC / "src").exists():
    SRC = SRC / "src"
# Frozen reference seed family used for the retained release outputs. An
# explicit environment variable can still select another seed family.
SEED_OFFSET = int(os.environ.get("PERTURBATION_SEED_OFFSET", "100000"))
OUTPUT = SRC / "network_perturbation_outputs"
CACHE = OUTPUT / "embedding_checkpoints"
OUTPUT.mkdir(parents=True, exist_ok=True)
CACHE.mkdir(parents=True, exist_ok=True)

PARAMETER_FILE = SRC / "data" / "cebra_config.csv"
RAW_FILE = SRC.parent / "data" / "psicon_time_series.pkl"
TABLE_FILE = SRC.parent / "data" / "table.csv"
for required_file in [PARAMETER_FILE, RAW_FILE, TABLE_FILE]:
    if not required_file.exists():
        raise FileNotFoundError(f"Missing required release file: {required_file}")

PHASES = ["rest", "meditation", "music", "movie"]
NETWORKS = ["Sub", "Vis", "SomMot", "DorsAttn", "Limbic",
            "SalVentAttn", "Default", "Cont"]

# These are the six stored subject positions used in the legacy panels. The
# positions refer to the frozen psilocybin-row ordering in the parameter
# table; the participant IDs are also saved in every output checkpoint.
STORED_SUBJECT_INDICES = [32, 53, 12, 22, 35, 39]

# Frozen 332-region module assignment from the original analysis. Values 0--7
# correspond to NETWORKS above. The first subcortical region was prepended to
# the original 331-row cortical module file.
ROI_NETWORK_LABELS = np.array([
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 6, 6, 6, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
    6, 6, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 6, 6, 3, 3, 3, 3,
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
    5, 5, 5, 5, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2,
    2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 5, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 5, 5, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
], dtype=int)

# Canonical run-length representation of the same atlas assignment. Keeping
# this compact audited form avoids relying on line wrapping in the long human-
# readable literal above.
ROI_NETWORK_RUNS = [
    (0, 32), (7, 17), (6, 7), (7, 23), (6, 59), (3, 14), (6, 2),
    (3, 16), (5, 20), (3, 2), (4, 10), (5, 4), (3, 2), (4, 10),
    (5, 6), (2, 14), (1, 24), (2, 7), (1, 23), (5, 2), (2, 15),
    (5, 2), (2, 21),
]
ROI_NETWORK_LABELS = np.concatenate([
    np.full(count, label, dtype=int) for label, count in ROI_NETWORK_RUNS
])
if ROI_NETWORK_LABELS.shape != (332,) or set(ROI_NETWORK_LABELS) != set(range(8)):
    raise RuntimeError("Invalid frozen ROI-to-network assignment.")


parameters = pd.read_csv(PARAMETER_FILE)
required_parameter_columns = {
    "subject_id", "session", "batch_size", "schedule_checkpoint",
    "effective_updates", "learning_rate"
}
if set(parameters.columns) != required_parameter_columns:
    raise ValueError("Unexpected parameter-table columns.")
if parameters.duplicated(["subject_id", "session"]).any():
    raise ValueError("Parameter table contains duplicate participant/session rows.")

psilocybin_parameters = parameters.loc[
    parameters["session"].eq("Psilocybin")
].reset_index(drop=True)
no_psilocybin_parameters = parameters.loc[
    parameters["session"].eq("No psilocybin")
].reset_index(drop=True)
if len(psilocybin_parameters) != 54 or len(no_psilocybin_parameters) != 54:
    raise ValueError("Expected 54 frozen rows for each session.")
if psilocybin_parameters["subject_id"].tolist() != no_psilocybin_parameters["subject_id"].tolist():
    raise ValueError("Psilocybin and no-psilocybin participant orders differ.")

with open(RAW_FILE, "rb") as handle:
    raw_time_series = pickle.load(handle)
recordings = pd.read_csv(TABLE_FILE)


def load_recording(pid, session):
    if session not in {"Psilocybin", "No psilocybin"}:
        raise ValueError(f"Unknown session label: {session!r}")
    table_session = session
    rows = recordings[
        recordings["participant_id"].eq(pid)
        & recordings["ses"].eq(table_session)
    ].copy()
    rows["task"] = pd.Categorical(rows["task"], PHASES, ordered=True)
    rows = rows.sort_values("task")
    if rows["task"].astype(str).tolist() != PHASES:
        raise ValueError(
            f"{pid}, {table_session}: missing or incorrectly ordered phases."
        )
    arrays = [np.asarray(raw_time_series[index][0], dtype=float) for index in rows.index]
    if any(array.ndim != 2 for array in arrays):
        raise ValueError(f"{pid}, {session}: expected ROI-by-time arrays.")
    concatenated = np.concatenate(arrays, axis=1)
    if concatenated.shape[0] != len(ROI_NETWORK_LABELS):
        raise ValueError(
            f"{pid}, {session}: expected {len(ROI_NETWORK_LABELS)} ROIs, "
            f"found {concatenated.shape[0]}."
        )
    return concatenated, [array.shape[1] for array in arrays]


def seed_everything(seed):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)


CHECKPOINTS = (20, 100, 200, 500, 1000, 2000, 5000, 10000)


def train_selected_model(time_by_roi, row):
    """Fit through the frozen checkpoint sequence and return the fitted model."""
    schedule_checkpoint = int(row.schedule_checkpoint)
    model = CEBRA(
        model_architecture="offset10-model", output_dimension=3,
        max_iterations=20, distance="cosine", conditional="time",
        device="cpu", verbose=False, learning_rate=float(row.learning_rate),
        temperature=1.12, batch_size=int(row.batch_size), time_offsets=10,
    )
    nominal_progress = 0
    for checkpoint in CHECKPOINTS:
        if checkpoint > schedule_checkpoint:
            break
        while nominal_progress < checkpoint:
            step = min(100, checkpoint - nominal_progress)
            model.set_params(max_iterations=step)
            model.partial_fit(time_by_roi)
            nominal_progress += step
        # Preserve the same checkpoint/transform sequence used previously.
        model.transform(time_by_roi)
    if nominal_progress != schedule_checkpoint:
        raise ValueError(
            f"Unsupported schedule checkpoint: {schedule_checkpoint}"
        )
    return model


def replace_network(psilocybin_roi_by_time, no_psilocybin_roi_by_time, network_index):
    """Replace one network with its length-matched no-psilocybin data."""
    output = psilocybin_roi_by_time.copy()
    target_length = psilocybin_roi_by_time.shape[1]
    no_psilocybin_length = no_psilocybin_roi_by_time.shape[1]
    mask = ROI_NETWORK_LABELS == network_index
    if not mask.any():
        raise ValueError(f"No ROIs assigned to network {network_index}.")
    if no_psilocybin_length >= target_length:
        replacement = no_psilocybin_roi_by_time[mask, :target_length]
    else:
        replacement = np.pad(
            no_psilocybin_roi_by_time[mask],
            ((0, 0), (0, target_length - no_psilocybin_length)),
            mode="constant", constant_values=0,
        )
    output[mask] = replacement
    return output


def phase_labels(durations):
    return np.concatenate([
        np.full(length, phase, dtype=int)
        for phase, length in enumerate(durations)
    ])


CLASSIFIER = OneVsRestClassifier(
    LogisticRegression(random_state=42, max_iter=1000)
)


def classification_accuracy(embedding, durations):
    labels = phase_labels(durations)
    fitted = clone(CLASSIFIER)
    fitted.fit(embedding, labels)
    return float(accuracy_score(labels, fitted.predict(embedding)))


def normalized_confusion(embedding, durations):
    labels = phase_labels(durations)
    fitted = clone(CLASSIFIER)
    fitted.fit(embedding, labels)
    matrix = confusion_matrix(labels, fitted.predict(embedding), labels=range(4))
    return matrix / matrix.sum(axis=1, keepdims=True)


def atomic_pickle(value, path):
    temporary = path.with_suffix(path.suffix + ".tmp")
    with open(temporary, "wb") as handle:
        pickle.dump(value, handle, pickle.HIGHEST_PROTOCOL)
    os.replace(temporary, path)


torch.set_num_threads(2)
try:
    torch.use_deterministic_algorithms(True)
except Exception:
    pass

output_rows = []
reference_confusions = []
substituted_confusions = []
participant_ids = []
for panel_position, stored_index in enumerate(STORED_SUBJECT_INDICES, start=1):
    psilocybin_row = psilocybin_parameters.iloc[stored_index]
    no_psilocybin_row = no_psilocybin_parameters.iloc[stored_index]
    pid = str(psilocybin_row.subject_id)
    cache_path = CACHE / f"P{panel_position}_{pid}.pkl"
    expected = {
        "participant_label": f"P{panel_position}",
        "stored_subject_index": stored_index,
        "subject_id": pid,
        "psilocybin_seed": 20000 + stored_index + SEED_OFFSET,
        "no_psilocybin_seed": 10000 + stored_index + SEED_OFFSET,
        "psilocybin_parameters": {
            "batch_size": int(psilocybin_row.batch_size),
            "schedule_checkpoint": int(psilocybin_row.schedule_checkpoint),
            "effective_updates": int(psilocybin_row.effective_updates),
            "learning_rate": float(psilocybin_row.learning_rate),
        },
        "no_psilocybin_parameters": {
            "batch_size": int(no_psilocybin_row.batch_size),
            "schedule_checkpoint": int(no_psilocybin_row.schedule_checkpoint),
            "effective_updates": int(no_psilocybin_row.effective_updates),
            "learning_rate": float(no_psilocybin_row.learning_rate),
        },
    }

    psilocybin_roi_by_time, psilocybin_durations = load_recording(
        pid, "Psilocybin"
    )
    no_psilocybin_roi_by_time, no_psilocybin_durations = load_recording(
        pid, "No psilocybin"
    )

    seed_everything(expected["no_psilocybin_seed"])
    no_psilocybin_model = train_selected_model(
        no_psilocybin_roi_by_time.T, no_psilocybin_row
    )
    no_psilocybin_embedding = np.asarray(
        no_psilocybin_model.transform(no_psilocybin_roi_by_time.T)
    ).copy()

    seed_everything(expected["psilocybin_seed"])
    psilocybin_model = train_selected_model(
        psilocybin_roi_by_time.T, psilocybin_row
    )
    psilocybin_embedding = np.asarray(
        psilocybin_model.transform(psilocybin_roi_by_time.T)
    ).copy()

    perturbed_embeddings = {}
    for network_index, network in enumerate(NETWORKS):
        perturbed = replace_network(
            psilocybin_roi_by_time, no_psilocybin_roi_by_time, network_index
        )
        perturbed_embeddings[network] = np.asarray(
            psilocybin_model.transform(perturbed.T)
        ).copy()

    item = expected | {
        "no_psilocybin_durations": no_psilocybin_durations,
        "psilocybin_durations": psilocybin_durations,
        "no_psilocybin_embedding": no_psilocybin_embedding,
        "psilocybin_embedding": psilocybin_embedding,
        "perturbed_embeddings": perturbed_embeddings,
    }
    atomic_pickle(item, cache_path)

    result = {
        "ParticipantLabel": item["participant_label"],
        "StoredSubjectIndex": item["stored_subject_index"],
        "NoPsilocybinAccuracy": classification_accuracy(
            item["no_psilocybin_embedding"], item["no_psilocybin_durations"]
        ),
        "PsilocybinAccuracy": classification_accuracy(
            item["psilocybin_embedding"], item["psilocybin_durations"]
        ),
    }
    for network in NETWORKS:
        result[f"{network}PerturbedAccuracy"] = classification_accuracy(
            item["perturbed_embeddings"][network], item["psilocybin_durations"]
        )
    reference_confusions.append(normalized_confusion(
        item["psilocybin_embedding"], item["psilocybin_durations"]
    ))
    substituted_confusions.append([
        normalized_confusion(item["perturbed_embeddings"][network],
                             item["psilocybin_durations"])
        for network in NETWORKS
    ])
    participant_ids.append(pid)
    output_rows.append(result)
    print(f"{panel_position:02d}/{len(STORED_SUBJECT_INDICES)} {pid} trained", flush=True)

output = pd.DataFrame(output_rows)
output_path = OUTPUT / "network_perturbation_accuracies.csv"
output.to_csv(output_path, index=False)
np.savez_compressed(
    OUTPUT / "network_perturbation_confusion_matrices.npz",
    stored_subject_indices=np.asarray(STORED_SUBJECT_INDICES),
    participant_ids=np.asarray(participant_ids),
    network_names=np.asarray(NETWORKS), phase_names=np.asarray(PHASES),
    psilocybin_reference=np.asarray(reference_confusions),
    network_substituted=np.asarray(substituted_confusions),
)
print(f"Saved {output_path}")

