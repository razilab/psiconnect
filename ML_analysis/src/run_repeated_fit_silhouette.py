"""Train repeated CEBRA fits and calculate phase-wise silhouette scores.

This is a fresh computational reproduction of Fig. 3c--f. It uses the frozen
recording-specific configuration in ``data/cebra_config.csv`` and stores every
new embedding before calculating cosine-distance silhouette coefficients.

Run from the repository root with::

    python src/run_repeated_fit_silhouette.py

Each participant/session/repeat is checkpointed independently. Every
invocation trains all 240 CEBRA models from scratch and overwrites the retained
example outputs.
"""

from pathlib import Path
import os
import pickle
import random

import numpy as np
import pandas as pd
import torch
from cebra import CEBRA
from sklearn.metrics import silhouette_samples


SRC = Path.cwd()
if SRC.name != "src" and (SRC / "src").exists():
    SRC = SRC / "src"

SEED_OFFSET = int(os.environ.get("SILHOUETTE_SEED_OFFSET", "200000"))
N_REPEATS = int(os.environ.get("SILHOUETTE_N_REPEATS", "10"))
OUTPUT = SRC / "silhouette_repeated_fit_outputs"
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
SESSIONS = ["No psilocybin", "Psilocybin"]

# True six lowest and six highest classification accuracies calculated from
# the saved published embeddings. Each group is in increasing-MEQ plot order.
LOW_INDICES = [4, 26, 45, 8, 19, 27]
HIGH_INDICES = [39, 51, 35, 22, 53, 32]
SELECTED_INDICES = LOW_INDICES + HIGH_INDICES

parameters = pd.read_csv(PARAMETER_FILE)
required_columns = {
    "subject_id", "session", "batch_size", "schedule_checkpoint",
    "effective_updates", "learning_rate"
}
if set(parameters.columns) != required_columns:
    raise ValueError("Unexpected parameter-table columns.")
if parameters.duplicated(["subject_id", "session"]).any():
    raise ValueError("Parameter table contains duplicate participant/session rows.")

session_parameters = {}
for session in SESSIONS:
    frame = parameters.loc[parameters["session"].eq(session)].reset_index(drop=True)
    if len(frame) != 54:
        raise ValueError(f"Expected 54 parameter rows for {session}, found {len(frame)}.")
    session_parameters[session] = frame
if (session_parameters[SESSIONS[0]]["subject_id"].tolist()
        != session_parameters[SESSIONS[1]]["subject_id"].tolist()):
    raise ValueError("Participant order differs between sessions.")

with open(RAW_FILE, "rb") as handle:
    raw_time_series = pickle.load(handle)
recordings = pd.read_csv(TABLE_FILE)


def load_recording(pid, session):
    rows = recordings[
        recordings["participant_id"].eq(pid)
        & recordings["ses"].eq(session)
    ].copy()
    rows["task"] = pd.Categorical(rows["task"], PHASES, ordered=True)
    rows = rows.sort_values("task")
    if rows["task"].astype(str).tolist() != PHASES:
        raise ValueError(f"{pid}, {session}: missing or incorrectly ordered phases.")
    arrays = [np.asarray(raw_time_series[index][0], dtype=float) for index in rows.index]
    if any(array.ndim != 2 for array in arrays):
        raise ValueError(f"{pid}, {session}: expected ROI-by-time arrays.")
    return np.concatenate(arrays, axis=1), [array.shape[1] for array in arrays]


def seed_everything(seed):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)


CHECKPOINTS = (20, 100, 200, 500, 1000, 2000, 5000, 10000)


def train_selected_model(time_by_roi, row):
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
        model.transform(time_by_roi)
    if nominal_progress != schedule_checkpoint:
        raise ValueError(
            f"Unsupported schedule checkpoint: {schedule_checkpoint}"
        )
    return model


def phase_labels(durations):
    return np.concatenate([
        np.full(length, phase_index, dtype=int)
        for phase_index, length in enumerate(durations)
    ])


def phase_silhouettes(embedding, durations):
    labels = phase_labels(durations)
    if len(labels) != len(embedding):
        raise ValueError("Embedding and phase-label lengths differ.")
    sample_scores = silhouette_samples(embedding, labels, metric="cosine")
    return {
        phase: float(sample_scores[labels == phase_index].mean())
        for phase_index, phase in enumerate(PHASES)
    }


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

score_rows = []
for session_index, session in enumerate(SESSIONS):
    frame = session_parameters[session]
    for cohort, indices in [("Low MEQ", LOW_INDICES), ("High MEQ", HIGH_INDICES)]:
        for stored_index in indices:
            row = frame.iloc[stored_index]
            pid = str(row.subject_id)
            roi_by_time, durations = load_recording(pid, session)
            time_by_roi = roi_by_time.T
            for repeat in range(1, N_REPEATS + 1):
                seed = SEED_OFFSET + session_index * 100000 + stored_index * 100 + repeat
                safe_session = session.lower().replace(" ", "_")
                cache_path = CACHE / f"{safe_session}_{stored_index:02d}_{pid}_fit{repeat:02d}.pkl"
                expected = {
                    "participant": pid,
                    "stored_subject_index": int(stored_index),
                    "session": session,
                    "cohort": cohort,
                    "repeat": repeat,
                    "seed": seed,
                    "batch_size": int(row.batch_size),
                    "schedule_checkpoint": int(row.schedule_checkpoint),
                    "effective_updates": int(row.effective_updates),
                    "learning_rate": float(row.learning_rate),
                }

                seed_everything(seed)
                model = train_selected_model(time_by_roi, row)
                embedding = np.asarray(model.transform(time_by_roi), dtype=np.float32)
                saved = {
                    **expected,
                    "durations": [int(value) for value in durations],
                    "embedding": embedding,
                    "phase_silhouettes": phase_silhouettes(embedding, durations),
                }
                atomic_pickle(saved, cache_path)

                for phase in PHASES:
                    score_rows.append({
                        "Condition": session,
                        "Cohort": cohort,
                        "StoredSubjectIndex": int(stored_index),
                        "Participant": pid,
                        "Phase": phase,
                        "Repeat": repeat,
                        "Seed": seed,
                        "Silhouette": saved["phase_silhouettes"][phase],
                    })
                print(
                    f"[trained] {session} {pid} fit {repeat}/{N_REPEATS} "
                    f"(schedule_checkpoint={int(row.schedule_checkpoint)}, "
                    f"effective_updates={int(row.effective_updates)})",
                    flush=True,
                )

scores = pd.DataFrame(score_rows)
scores.to_csv(OUTPUT / "silhouette_repeated_fit_scores.csv", index=False)

# A compact, participant-keyed bundle makes the full set of newly generated
# embeddings convenient for downstream reuse without opening 240 checkpoints.
bundle = {session: {} for session in SESSIONS}
for checkpoint in sorted(CACHE.glob("*.pkl")):
    with open(checkpoint, "rb") as handle:
        saved = pickle.load(handle)
    bundle[saved["session"]].setdefault(saved["participant"], []).append({
        "repeat": saved["repeat"],
        "seed": saved["seed"],
        "durations": saved["durations"],
        "embedding": saved["embedding"],
    })
for session in bundle:
    for pid in bundle[session]:
        bundle[session][pid].sort(key=lambda item: item["repeat"])
atomic_pickle(bundle, OUTPUT / "silhouette_repeated_fit_embeddings.pkl")

print(f"Saved {len(scores)} phase-level scores to {OUTPUT}")

