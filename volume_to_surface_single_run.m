function volume_to_surface_single_run(subj,ses,run_str,task,GSR)
% subj        = 'sub-PC001';
% ses         = 'ses-01';
% run_str     = '1';
% task        = 'music'
% GSR         = false;

% NOTE: Set dir_base to the root of PsiConnect dataset.

dir_base    = '/path/to/PsiConnect';
space       = 'space-MNI152NLin2009cAsym';

if GSR
    data_dir = fullfile(dir_base,'derivatives','tedana-0.0.12-GLM-GSR');
else
    data_dir = fullfile(dir_base,'derivatives','tedana-0.0.12-GLM');
end

% fmriprep preprocessed
dir_in      = fullfile(data_dir,subj,ses,'func',['task-',task]);
f_in        = fullfile(dir_in, [subj,'_',ses,'_','task-',task,'_','run-',run_str,'_',space,'_desc-optcomGLM_bold.nii.gz']);
dir_out     = dir_in;

volume_to_surface(f_in,dir_out)
