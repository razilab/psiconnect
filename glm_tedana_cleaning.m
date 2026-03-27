clear
addpath("/path/to/spm") % load latest spm

% we'll use bids-matlab to parse BIDS file names. You can download it from
% GitHub: https://github.com/bids-standard/bids-matlab
addpath("/path/to/bids-matlab")

%% define paths and variables
dir_base        = 'PsiConnect';
dir_bids        = fullfile(dir_base,'bids');
tedana_v        = '0.0.12';
dir_fmriprep    = fullfile(dir_base,'derivatives','fmriprep-22.0.2');

TR              = 0.91;     % repetition time
ignore_frames   = 5;        % first few frames to ignore
GLM_overwrite   = false;    % 1 = delete old subject-specific GLM subfolders
GSR             = false;    % also regress the global signal
HPF             = 1000;     % high-pass filter cutoff in seconds
whiten          = false;    % pre-whiten using AR(1) model
tedort          = false;    % true if rejected components have been made orthogonal to accepted ones using --tedort in tedana

regressor_names = [...
    "framewise_displacement"; ...
    "white_matter"; ...
    "csf"];

if GSR
    regressor_names = [regressor_names; "global_signal"];
end

tasks           = {'meditation','movie','music','rest'}
space           = 'space-MNI152NLin2009cAsym';

batch_size      = max(1,feature('numcores') - 2); % n parallel processes (available CPUs - 2)

%% read BIDS folder to find all subjects, sessions, scans, etc
BIDS            = spm_BIDS(dir_bids);

%% loop over all subjects and sessions (the rows ofthe BIDS.subjects table)

delete(gcp('nocreate')) % delete previous parpool if active

poolobj     = parpool(batch_size)
row_n       = length(BIDS.subjects);
tasks_n     = length(tasks);

for i_batch = 1:batch_size:row_n
    mbatch          = cell(row_n,tasks_n);
    K               = cell(row_n,tasks_n);
    
    tic

    parfor i_row = i_batch:min((i_batch + batch_size - 1),row_n)
        % read subject name and session name
        subj        = BIDS.subjects(i_row).name;
        ses         = BIDS.subjects(i_row).session;
        
        % define functional folder containing the preprocessed BOLD file
        dir_func    = fullfile(dir_fmriprep,subj,ses,'func');
    
        for i_task = 1:tasks_n
            task    = tasks{i_task};
            
            disp(['Processing: ',subj,' ',ses,' ',task])
        
            % define folder containing the cleaned BOLD file
            dir_tedana  = fullfile(dir_base,'derivatives',...
                                ['tedana-',tedana_v],subj,ses,['task-',task]);
            % ensure that functional folder exists
            if ~isfolder(dir_tedana)
                warning(['Skipping: ',subj,' ',ses,' ',task,': no tedana dir'])
                continue
            end
            
            % find optimally combined BOLD NIFTI file
            f_bold  = dir(fullfile(dir_tedana,['*',space,'*optcom_bold.nii.gz']));
            if isempty(f_bold)
                warning(['Skipping: ',subj,' ',ses,' ',task,': no BOLD file'])
                continue
            end
            % temporarily unzip nii.gz file (will delete at the end)
            f_bold  = gunzip(fullfile(f_bold.folder,f_bold.name));
            % get folder name and file name
            f_bold  = dir(f_bold{1});
    
            % define output folder for GLM results
            if GSR
                dir_glm = fullfile(dir_base,'derivatives',...
                    ['tedana-',tedana_v,'-GLM-GSR'],subj,ses,'func',['task-',task]);
            else
                dir_glm = fullfile(dir_base,'derivatives',...
                    ['tedana-',tedana_v,'-GLM'],subj,ses,'func',['task-',task]);
            end
    
            % load all frames using spm_select
            bold    = spm_select('ExtFPList', f_bold.folder,f_bold.name);
            % ignore first few frames
            bold    = bold(ignore_frames+1:end,:);
            
            % delete old subject-specific GLM folder (if requested) and create new one
            f_gz  = dir(fullfile(dir_glm,'*GLM_bold.nii.gz'));
            if ~isempty(f_gz) && ~GLM_overwrite
                warning(['Skipping existing task: ',subj,' ',ses,' ',task'])
                continue
            else
                if exist(dir_glm,'dir'); rmdir(dir_glm,'s'); end
                mkdir(dir_glm)
            end
                        
            % find confounds tsv file
            f_conf = dir(fullfile(dir_func,['*task-',task,'*confounds_timeseries.tsv']));
            f_conf = fullfile(f_conf.folder,f_conf.name);
            % read confound time series from tsv file using bids-matlab util
            regressors  = bids.util.tsvread(f_conf);
            % select confounds (matrix of regressors must be named 'R')
            R               = [];
            for i_conf = 1:length(regressor_names)
                R           = [R, regressors.(regressor_names(i_conf))];
            end
            % add rejected tedana components
            tedana_decision = tdfread(fullfile(dir_tedana,'desc-tedana_metrics.tsv'));
            idx_rejected    = strcmp(tedana_decision.classification,"rejected");
            if tedort
                tedana_ICA  = struct2table(tdfread(fullfile(dir_tedana,'desc-ICAOrth_mixing.tsv')));
            else
                tedana_ICA  = struct2table(tdfread(fullfile(dir_tedana,'desc-ICA_mixing.tsv')));
            end
            tedana_rejected = table2array(tedana_ICA(:,idx_rejected));
            R               = [R,tedana_rejected];
            % add "constant" regressor name and tedana components before saving
            regressor_names_all     = ["constant";regressor_names];
            for i_rej = 1:size(tedana_rejected,2)
                regressor_names_all = [regressor_names_all;['tedana_ICA_rejected_',num2str(i_rej)]];
            end
    
            % ignore first few frames
            R           = R(ignore_frames+1:end,:);
    
            % high-pass filter the confounds
            K{i_row,i_task}.RT      = TR;
            K{i_row,i_task}.row     = 1:size(R,1);
            K{i_row,i_task}.HParam  = HPF; %cut-off in seconds
            nK                      = spm_filter(K{i_row,i_task});
            R                       = spm_filter(nK,R);
            % alternatively, do not filter R but add the Discrete Cosine
            % Transform basis functions as regressors in R and turn off the
            % HPF in the GLM specification below:
            % R = [R, nK.X0];
            %for i_DCT = 1:size(nK.X0,2)
            %    regressor_names_tosave = [regressor_names_tosave;['DCT_',num2str(i_DCT)]];
            %end
            % mbatch{i_row,i_task}{1}.spm.stats.fmri_spec.sess.hpf = 9999;
            
            % save selected confounds
            f_conf_selected = fullfile(dir_glm,'confounds.mat');
            parsave(f_conf_selected,R,regressor_names_all)
            
            % find brain mask NIFTI file
            f_brainmask = dir(fullfile(dir_tedana,'*adaptiveGoodSignalThr_mask.nii.gz'));
            % temporarily unzip nii.gz file (will delete at the end)
            f_brainmask = gunzip(fullfile(f_brainmask.folder,f_brainmask.name));
            
            f_SPM       = fullfile(dir_glm,'SPM.mat');
            
            mbatch{i_row,i_task} = {};

            % GLM specification
            %------------------------------------------------------------------
            mbatch{i_row,i_task}{1}.spm.stats.fmri_spec.dir               = {dir_glm};
            mbatch{i_row,i_task}{1}.spm.stats.fmri_spec.timing.units      = 'scans';
            mbatch{i_row,i_task}{1}.spm.stats.fmri_spec.timing.RT         = TR;
            mbatch{i_row,i_task}{1}.spm.stats.fmri_spec.sess.scans        = cellstr(bold);
            mbatch{i_row,i_task}{1}.spm.stats.fmri_spec.sess.multi_reg    = {f_conf_selected};
            mbatch{i_row,i_task}{1}.spm.stats.fmri_spec.sess.hpf          = HPF;
            mbatch{i_row,i_task}{1}.spm.stats.fmri_spec.mask              = {f_brainmask{1}};
            mbatch{i_row,i_task}{1}.spm.stats.fmri_spec.mthresh           = -Inf;
            if whiten
                mbatch{i_row,i_task}{1}.spm.stats.fmri_spec.cvi           = 'AR(1)';
            else
                mbatch{i_row,i_task}{1}.spm.stats.fmri_spec.cvi           = 'none';
            end
    
            % GLM estimation
            %------------------------------------------------------------------
            mbatch{i_row,i_task}{2}.spm.stats.fmri_est.spmmat             = {f_SPM};
    
            % Extraction of time series from VOIs
            %------------------------------------------------------------------
            mbatch{i_row,i_task}{3}.spm.util.voi.spmmat          	= {f_SPM};
            mbatch{i_row,i_task}{3}.spm.util.voi.adjust          	= NaN;
            mbatch{i_row,i_task}{3}.spm.util.voi.session          	= 1;
            mbatch{i_row,i_task}{3}.spm.util.voi.name                = 'BRAIN';
            mbatch{i_row,i_task}{3}.spm.util.voi.roi{1}.mask.image   = {fullfile(dir_glm,'mask.nii')};
            mbatch{i_row,i_task}{3}.spm.util.voi.expression          = 'i1';
            
            % run GLM batch
            %------------------------------------------------------------------
            spm_jobman('run',mbatch{i_row,i_task});
            
            % delete unzipped mask file
            delete(f_brainmask{1})
    
            %------------------------------------------------------------------
            % Read 4D nifti. V contains Nifti header information in SPM format
            f_bold          = fullfile(f_bold.folder,f_bold.name);
            V               = spm_vol(f_bold);
            V               = V(ignore_frames+1:end);
            dims            = V(1).dim;
            numvols         = size(V,1);
    
            VOI             = load(fullfile(dir_glm, 'VOI_BRAIN_1.mat'),'xY');
            assert(numvols == size(VOI.xY.y,1))
    
            % load brain mask
            f_brainmask     = fullfile(dir_glm,'VOI_BRAIN_mask.nii');
            vol_brainmask  	= spm_vol(f_brainmask);
            brain_mask      = logical(spm_read_vols(vol_brainmask));
            assert(all(dims == size(brain_mask)))
    
            % fill only voxels within the brain mask
            Y_masked                = zeros(numvols,prod(dims));
            Y_masked(:,brain_mask)  = VOI.xY.y;
            % reshape it to 4D
            Y_masked                = reshape(Y_masked',[dims,numvols]);
            
            % set ouput file name
            f_out                   = bids.File(f_bold);
            f_out.entities.desc     = [f_out.entities.desc,'GLM'];
            f_out                   = fullfile(dir_glm,f_out.filename);
    
            % We have to write a single volume at a time. The idea is to keep 
            % the original nifti header in V, which means that the first few 
            % volumes will be empty (if ignore_frames > 0)
            for v = 1:numvols
                % Re-use the original V to get correct headers, but remove
                % the scaling info so SPM can rescale appropriately. Same 
                % scale factor is used for all volumes.
                thisV               = rmfield(V(v),'pinfo');
    
                % Choose a data type. float32 is a good compromise between
                % low digitization error and small file size
                thisV.dt(1)         = spm_type('float32');
    
                % set the filename so we don't overwrite existing
                thisV.fname         = f_out;
    
                % And write this volume
                spm_write_vol(thisV,Y_masked(:,:,:,v));
            end
            % compress nifti file
            system(['gzip ',f_out])
    
            % delete temporarily unzipped NIFTI files
            delete(f_bold)
            
        end
    end

    tEnd    = datenum(0,0,0,0,0,toc); % time since previous 'tic'
    fprintf('Elapsed time is %s\n', datestr(tEnd,'HH:MM:SS'))
end

delete(poolobj)


function parsave(path,R,regressor_names_all)
    save(path,'R','regressor_names_all')
end