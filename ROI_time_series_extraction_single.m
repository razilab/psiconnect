function ROI_time_series_extraction_single(i_row)

addpath("/path/to/spm12") % SPM12: https://www.fil.ion.ucl.ac.uk/spm/

i_row           = str2double(i_row);

%% define paths and parameters

% name of parcellation dir inside derivatives/parcellations
parc_dirname    = "Schaefer2018_300Parcels_Tian_Subcortex"
% name of masks dir inside parcellation dir defined above
masks_dirname   = "332_ROIs"

intersect_GM    = true;    % true = only keep voxels within the GM mask
ts_overwrite    = true;     % overwrite existing results

smooth          = false;    % true = load smoothed data
GSR             = false;    % true = load data after GSR

run_str         = "1";
pipeline        = "tedanaGLM"
ignore_frames   = 5;        % first few frames to ignore
thr_GM          = "0.35";   % GM probabistic map threshold

v_tedana        = "0.0.12";
v_fmriprep      = "22.0.2";
v_fsl           = "6.0.7.10";

% define paths and variables
dir_base        = "/path/to/PsiConnect";
dir_deriv       = fullfile(dir_base,"derivatives");
dir_masks       = fullfile(dir_deriv,"parcellations",parc_dirname,"masks",masks_dirname);
dir_ts          = fullfile(dir_deriv,"timeseries",parc_dirname,masks_dirname); % time series
dir_fmriprep    = fullfile(dir_deriv,"fmriprep-" + v_fmriprep);

% find all ROI masks
ROI_paths       = dir(fullfile(dir_masks,"*.nii"));
ROI_names       = erase({ROI_paths.name}',".nii");
ROI_n           = length(ROI_names);
ROI_masks       = fullfile({ROI_paths.folder}',{ROI_paths.name}');
assert(~isempty(ROI_masks))

% set first image as reference (i.e. only reslice images 2,...n)
flags.which     = 1;
% use nearest-neighbour interpolation method
flags.interp    = 0;
% don't mask
flags.mask      = 0;
% don't compute mean image
flags.mean      = 0;
% don't wrap
flags.wrap      = [0,0,0];

dir_glm_name    = "tedana-" + v_tedana + "-GLM";
if smooth; dir_glm_name = "smooth-" + dir_glm_name; end
if GSR; dir_glm_name = dir_glm_name + "-GSR"; end

%% read BIDS folder to find all subjects, sessions, scans, etc
BIDS = bids_filenames_to_table(fullfile(dir_deriv,dir_glm_name,"**/*_bold.nii.gz"),false);

%% reslice

% read subject name and session name
subj                = BIDS.participant_id(i_row);
ses                 = BIDS.ses(i_row);
task                = BIDS.task(i_row);

disp("Processing: " + subj + " " + ses + " " + task)

% define GLM folder
dir_glm         = fullfile(dir_deriv,dir_glm_name,subj,ses,"func",task);

% try to find anat folder
dir_anat	    = dir(fullfile(dir_fmriprep,subj,"**/anat"));
% skip session if these files or folders are missing
if isempty(dir_anat)
    error("Session skipped: missing anat folder")
end
% get first instance of anat folder (it differs among subjects)
dir_anat        = dir_anat.folder;
% try to find GM probabilistic mask
f_GM          = dir(fullfile(dir_anat, "*MNI152*GM_probseg.nii.gz"));
% try to find cleaned BOLD nifti file
f_bold      = dir(fullfile(dir_glm, "*_bold.nii.gz"));
% skip session if these files or folders are missing
if isempty(dir_anat) || isempty(f_GM) || isempty(f_bold)
    error("Session skipped: missing anat folder, GM mask, or tedana BOLD file")
end

% delete old subject-specific timeseries folder (if requested)
% and create new one
dir_out         = fullfile(dir_ts,subj,ses,task);
f_previous      = dir(fullfile(dir_out,"*timeseries*pipeline*.mat"));
if ~isempty(f_previous) && ~ts_overwrite
    error("Skipped existing task: " + subj + " " + ses + " " + task)
else
    if exist(dir_out,"dir"); rmdir(dir_out,"s"); end
    mkdir(dir_out)
end

% load BOLD file
f_bold          = fullfile(f_bold.folder,f_bold.name);
% unzip
f_bold          = gunzip(f_bold,dir_out);
f_bold          = f_bold{1};
vol_boldclean   = spm_vol(char(f_bold));
bold            = spm_read_vols(vol_boldclean);
dims            = vol_boldclean(1).dim;
numvols         = size(vol_boldclean,1);

% copy probabilistic GM mask to output folder
f_GM            = fullfile(f_GM.folder,f_GM.name);
f_GM_copy       = fullfile(dir_out,"GM_thresholded_mask.nii.gz");
if isfile(f_GM_copy); delete(f_GM_copy);end
copyfile(f_GM,f_GM_copy)
% threshold
f_GM            = f_GM_copy;
% NOTE: 'module load fsl' is an HPC-specific command (Monash MASSIVE cluster).
% On a local machine, ensure FSL is installed and on your PATH instead.
system("module load fsl/" + v_fsl + " && "...
    + "fslmaths " + f_GM + " -thr " + thr_GM + " -bin " + f_GM);
% unzip
f_GM            = gunzip(f_GM);
f_GM            = f_GM{1};

% move masks to be resliced to output folder
copyfile(fullfile(dir_masks,"*.nii"),dir_out)
ROI_masks       = fullfile(dir_out,{ROI_paths.name}');

% reslice thresholded GM mask and ROI masks
prefix = subj + "_" + ses + "_" + task + "_run-" + run_str + "_";
% first file is the reference, the following ones will be resliced
f_reslice = char(strcat(vertcat({f_bold},{f_GM},ROI_masks),",1"));

% use custom prefix
flags.prefix  = prefix;
% reslice
spm_reslice(f_reslice,flags)

% load resliced GM mask
f_GM        = fullfile(dir_out,prefix + "GM_thresholded_mask.nii");
vol_GM      = spm_vol(char(f_GM));
GM          = spm_read_vols(vol_GM) > 0;
dims2       = size(GM);
assert(all(dims2 == dims))
% compress
gzip(f_GM);

% extract ROI time series
time_series     = cell(1,ROI_n); % we don't know the length yet
for i = 1:ROI_n
    ROI_name    = ROI_names{i};

    % load resliced ROI
    f_ROI       = fullfile(dir_out,prefix + ROI_name + ".nii");
    vol_ROI     = spm_vol(char(f_ROI));
    ROI         = spm_read_vols(vol_ROI) > 0;
    dims3       = size(ROI);
    assert(all(dims3 == dims))

    % intersect ROI and GM (if intersection is not empty)
    if intersect_GM
        temp        = ROI & GM;
        if sum(temp(:)) > 0
            ROI     = temp;
        else
            warning("did not intersect GM mask and ROI (%s) " + ...
                "since it  would be empty",ROI_name)
        end
    end
    % send warning if ROI mask is very small
    if sum(ROI(:)) < 6
        warning("ROI (%s) has < 6 voxels",ROI_name)
    end

    % save intersection as NIFTI file
    V           = vol_GM;
    V.pinfo(1:2) = [1;0];
    V.dt(1)     = spm_type('uint8');
    f_ROI_inter = fullfile(dir_out,ROI_name + ".nii");
    V.fname     = char(f_ROI_inter);
    spm_write_vol(V,uint8(ROI));
    % compress
    system("gzip -f " + f_ROI_inter);

    % apply ROI mask to cleaned BOLD
    bold_masked     = reshape(bold,[prod(dims),numvols]);
    bold_masked     = bold_masked(ROI(:),:);
    % compute first principal component
    [U,S,V]         = svd(bold_masked',"econ","vector");
    pc1             = U(:,1) * S(1);
    % scale by number of voxels
    pc1             = pc1 / sqrt(size(U,2));
    % the sign of pc1 is arbitrary: align with time series
    pc1             = pc1 * sign(sum(V(:,1)));
    time_series{i}  = pc1;
end

% convert cell array to 2D array (time x ROIs)
time_series         = cell2mat(time_series);
% ignore first few volumes
time_series         = time_series(ignore_frames+1:end,:);

path = fullfile(dir_out,subj + "_" + ses + "_" ...
    + task + "_run-" + run_str + "_timeseries-" + pipeline + ".mat");
save(path,"time_series","ROI_names")

% delete temporarily unzipped files
delete(f_GM_copy) % thresholded GM mask
% delete any remaining .nii files
niftis = dir(fullfile(dir_out,"*.nii"));
niftis = fullfile({niftis.folder}',{niftis.name}');
delete(niftis{:})
