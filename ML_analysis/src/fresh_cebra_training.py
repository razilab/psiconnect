# %% [markdown]
# # Fresh CEBRA reproduction from saved recording-wise parameters
#
# This notebook reruns CEBRA for the psilocybin recordings using the
# saved config table in `data/cebra_config.csv`. Every execution
# trains all 54 CEBRA models from scratch. The fixed seed family reproduces the
# canonical first seed from the earlier three-seed regeneration; it does not
# guarantee a particular correlation.

# %%
from pathlib import Path
import os
import pickle
import random

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import torch
from cebra import CEBRA
from matplotlib.animation import FuncAnimation, PillowWriter
from scipy.stats import pearsonr
from sklearn.base import clone
from sklearn.metrics import accuracy_score
from sklearn.svm import SVC
from sklearn.linear_model import LogisticRegression
from sklearn.multiclass import OneVsRestClassifier
from IPython.display import display, Image

SRC = Path.cwd()
if SRC.name != 'src' and (SRC / 'src').exists():
    SRC = SRC / 'src'
OUTPUT = SRC / 'fresh_cebra_outputs'
OUTPUT.mkdir(parents=True, exist_ok=True)

PARAMETER_FILE = SRC / 'data' / 'cebra_config.csv'
RAW_FILE = SRC.parent / 'data' / 'psicon_time_series.pkl'
TABLE_FILE = SRC.parent / 'data' / 'table.csv'
MEQ_FILE = SRC.parent / 'data' / 'MEQ30_MEAN.csv'

for required_file in [PARAMETER_FILE, RAW_FILE, TABLE_FILE, MEQ_FILE]:
    if not required_file.exists():
        raise FileNotFoundError(f'Missing required release file: {required_file}')
print(f'Raw data: {RAW_FILE}')
print(f'Parameter table: {PARAMETER_FILE}')

# %% [markdown]
# ## Load the saved CEBRA configs and source time series

# %%
parameters = pd.read_csv(PARAMETER_FILE)
required_columns = {
    'subject_id', 'session', 'batch_size', 'schedule_checkpoint',
    'effective_updates', 'learning_rate'
}
if set(parameters.columns) != required_columns:
    raise ValueError(f'Parameter columns must be exactly {sorted(required_columns)}')
parameters = parameters.loc[parameters['session'].eq('Psilocybin')].reset_index(drop=True)
if len(parameters) != 54 or parameters['subject_id'].duplicated().any():
    raise ValueError('Expected one psilocybin parameter row for each of 54 participants.')

with open(RAW_FILE, 'rb') as handle:
    raw_time_series = pickle.load(handle)
recordings = pd.read_csv(TABLE_FILE)
meq = pd.read_csv(MEQ_FILE, encoding='utf-8-sig')
meq['Participant'] = meq['participant_id'].str.extract(r'(PC\d+)')[0]
meq_map = meq.drop_duplicates('Participant').set_index('Participant')['MEQ30_MEAN']

PHASES = ['rest', 'meditation', 'music', 'movie']
PHASE_COLORS = dict(zip(PHASES, ['#ed2f92', '#2d348b', '#087437', '#f5a623']))
participants = parameters['subject_id'].tolist()

def load_recording(pid, session='Psilocybin'):
    rows = recordings[(recordings['participant_id'] == pid) &
                      (recordings['ses'] == session)].copy()
    rows['task'] = pd.Categorical(rows['task'], PHASES, ordered=True)
    rows = rows.sort_values('task')
    if rows['task'].astype(str).tolist() != PHASES:
        raise ValueError(f'{pid}, {session}: incomplete or incorrectly ordered phases.')
    arrays = [np.asarray(raw_time_series[index][0], dtype=float) for index in rows.index]
    return np.concatenate(arrays, axis=1).T, [array.shape[1] for array in arrays]

# %% [markdown]
# ## Run fresh CEBRA models
#
# The seed for participant position `i` is `20000 + i`. Training follows the
# original checkpoint sequence and transforms at every checkpoint before
# continuing. Models are always trained from scratch.

# %%
SEED_BASE = 20000
CHECKPOINTS = (20, 100, 200, 500, 1000, 2000, 5000, 10000)

def seed_everything(seed):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)

def train_selected(X, row):
    schedule_checkpoint = int(row.schedule_checkpoint)
    model = CEBRA(
        model_architecture='offset10-model', output_dimension=3,
        max_iterations=20, distance='cosine', conditional='time',
        device='cpu', verbose=False, learning_rate=float(row.learning_rate),
        temperature=1.12, batch_size=int(row.batch_size), time_offsets=10,
    )
    nominal_progress = 0
    embedding = None
    for checkpoint in CHECKPOINTS:
        if checkpoint > schedule_checkpoint:
            break
        while nominal_progress < checkpoint:
            step = min(100, checkpoint - nominal_progress)
            model.set_params(max_iterations=step)
            model.partial_fit(X)
            nominal_progress += step
        embedding = model.transform(X)
    if nominal_progress != schedule_checkpoint or embedding is None:
        raise ValueError(
            f'Unsupported schedule checkpoint: {schedule_checkpoint}'
        )
    return np.asarray(embedding).copy()

def atomic_pickle(value, path):
    temporary = path.with_suffix(path.suffix + '.tmp')
    with open(temporary, 'wb') as handle:
        pickle.dump(value, handle, pickle.HIGHEST_PROTOCOL)
    os.replace(temporary, path)

torch.set_num_threads(2)
try:
    torch.use_deterministic_algorithms(True)
except Exception:
    pass

embeddings = {'Psilocybin': {}}
durations = {}
for i, row in parameters.iterrows():
    pid = row.subject_id
    seed = SEED_BASE + i
    X, phase_lengths = load_recording(pid)
    seed_everything(seed)
    embedding = train_selected(X, row)
    embeddings['Psilocybin'][pid] = embedding
    durations[pid] = phase_lengths
    print(f'{i + 1:02d}/{len(parameters)} {pid}', flush=True)

atomic_pickle(embeddings['Psilocybin'], OUTPUT / 'fresh_psilocybin_cebra_embeddings.pkl')
pd.DataFrame([
    {'Participant': pid, 'Condition': 'Psilocybin', **dict(zip(PHASES, durations[pid]))}
    for pid in participants
]).to_csv(OUTPUT / 'phase_durations.csv', index=False)

# %% [markdown]
# ## Classification accuracy and MEQ correlation

# %%
def phase_labels(phase_lengths):
    return np.concatenate([np.full(n, label, dtype=int)
                           for label, n in enumerate(phase_lengths)])

linear_classifiers_dict = {
    0: OneVsRestClassifier(
        LogisticRegression(random_state=42, max_iter=1000)
    ),
    1: SVC(
        kernel='linear', C=0.025, class_weight='balanced',
        decision_function_shape='ovr',
    ),
}

classifier = linear_classifiers_dict[0]

def classification_accuracy(embedding, phase_lengths):
    labels = phase_labels(phase_lengths)
    fitted_classifier = clone(classifier)
    fitted_classifier.fit(embedding, labels)
    return float(accuracy_score(labels, fitted_classifier.predict(embedding)))

rows = []
for pid in participants:
    accuracy = classification_accuracy(embeddings['Psilocybin'][pid], durations[pid])
    rows.append({'Participant': pid, 'Session': 'Psilocybin',
                 'Accuracy': accuracy, 'MEQ': float(meq_map[pid])})
results = pd.DataFrame(rows)
results.to_csv(OUTPUT / 'classification_subject_results.csv', index=False)

subset = results.copy()
r, p = pearsonr(subset['Accuracy'], subset['MEQ'])
fig, ax = plt.subplots(figsize=(5.5, 4.5))
ax.scatter(subset['Accuracy'], subset['MEQ'], s=27, color='#f28e2b', alpha=0.85)
coef = np.polyfit(subset['Accuracy'], subset['MEQ'], 1)
xx = np.linspace(subset['Accuracy'].min(), subset['Accuracy'].max(), 200)
ax.plot(xx, np.polyval(coef, xx), color='#2878b5', lw=2)
ax.set(title=f'r = {r:.2f}, p = {p:.3g}',
       xlabel='Classification accuracy', ylabel='MEQ30 mean score')
fig.tight_layout()
fig.savefig(OUTPUT / 'figure_classification_accuracy_meq.png', dpi=300,
            bbox_inches='tight')
plt.show()

correlation_summary = pd.DataFrame([{
    'Session': 'Psilocybin', 'N': len(subset), 'PearsonR': round(r, 2),
    'PValue': p, 'MeanAccuracy': subset['Accuracy'].mean(),
}])
correlation_summary.to_csv(OUTPUT / 'classification_meq_correlations.csv', index=False)
display(correlation_summary)

# %% [markdown]
# ## Four-subject CEBRA animations

# %%
def scatter_embedding(ax, pid, session, point_size=1.8, alpha=0.85):
    embedding = embeddings[session][pid]
    labels = phase_labels(durations[pid])
    for label, phase in enumerate(PHASES):
        points = embedding[labels == label]
        ax.scatter(points[:, 0], points[:, 1], points[:, 2], s=point_size,
                   color=PHASE_COLORS[phase], alpha=alpha, depthshade=False)
    ax.set_axis_off()
    ax.set_box_aspect((1, 1, 1))

gif_ids = ['PC008', 'PC203', 'PC233', 'PC209']

fig = plt.figure(figsize=(10, 3.8))
gif_axes = []
for col, pid in enumerate(gif_ids):
    ax = fig.add_subplot(1, 4, col + 1, projection='3d')
    scatter_embedding(ax, pid, 'Psilocybin')
    ax.set_title(f'MEQ = {meq_map[pid]:.1f}', fontsize=10)
    gif_axes.append(ax)
fig.text(0.26, 0.91, 'Low MEQ', ha='center', fontsize=12)
fig.text(0.74, 0.91, 'High MEQ', ha='center', fontsize=12)
fig.tight_layout(rect=(0, 0, 1, 0.84))

def rotate(angle):
    for ax in gif_axes:
        ax.view_init(elev=18, azim=angle)
    return gif_axes

rotation = FuncAnimation(fig, rotate, frames=np.arange(0, 360, 4), interval=70, blit=False)
rotation_path = OUTPUT / 'CEBRA_psilocybin_low_high_rotation.gif'
rotation.save(rotation_path, writer=PillowWriter(fps=15), dpi=110)
plt.close(fig)
display(Image(filename=str(rotation_path)))

fig = plt.figure(figsize=(10, 3.8))
progress_axes = [fig.add_subplot(1, 4, i + 1, projection='3d') for i in range(4)]
limits = {}
for pid in gif_ids:
    embedding = embeddings['Psilocybin'][pid]
    limits[pid] = [(embedding[:, dim].min(), embedding[:, dim].max()) for dim in range(3)]
fig.text(0.26, 0.89, 'Low MEQ', ha='center', fontsize=12)
fig.text(0.74, 0.89, 'High MEQ', ha='center', fontsize=12)
fig.subplots_adjust(left=0.01, right=0.99, bottom=0.03, top=0.78, wspace=0.02)

def show_progress(frame):
    fraction = (frame + 1) / 120
    for ax, pid in zip(progress_axes, gif_ids):
        ax.cla()
        embedding = embeddings['Psilocybin'][pid]
        labels = phase_labels(durations[pid])
        n_visible = max(1, int(fraction * len(embedding)))
        for label, phase in enumerate(PHASES):
            visible = np.arange(len(embedding)) < n_visible
            points = embedding[(labels == label) & visible]
            if len(points):
                ax.scatter(points[:, 0], points[:, 1], points[:, 2], s=1.8,
                           color=PHASE_COLORS[phase], alpha=0.85, depthshade=False)
        ax.set_xlim(*limits[pid][0]); ax.set_ylim(*limits[pid][1]); ax.set_zlim(*limits[pid][2])
        ax.set_axis_off(); ax.set_box_aspect((1, 1, 1))
        ax.set_title(f'MEQ = {meq_map[pid]:.1f}', fontsize=10)
    fig.suptitle(f'Psilocybin trajectory completion: {fraction:.0%}', fontsize=12, y=0.98)
    return progress_axes

progression = FuncAnimation(fig, show_progress, frames=120, interval=60, blit=False)
progression_path = OUTPUT / 'CEBRA_psilocybin_low_high_temporal_progression.gif'
progression.save(progression_path, writer=PillowWriter(fps=18), dpi=110)
plt.close(fig)
display(Image(filename=str(progression_path)))
print(f'Saved {rotation_path}')
print(f'Saved {progression_path}')
