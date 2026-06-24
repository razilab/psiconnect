function spDCM_single_run(subj,ses,task,run_str)
%Run spectral DCM on a single run

addpath('/path/to/spm12') % SPM12: https://www.fil.ion.ucl.ac.uk/spm/

% define paths and parameters

% name of parcellation dir inside derivatives/parcellations
parc_dirname    = 'your_parcellation_name'
% name of masks dir inside parcellation dir defined above
masks_dirname   = 'your_dir_name'

% define paths and variables
dir_base        = '/path/to/PsiConnect';
dir_deriv       = fullfile(dir_base,'derivatives');
dir_ts          = fullfile(dir_deriv,'timeseries',parc_dirname,masks_dirname); % time series
dir_DCM         = fullfile(dir_deriv,'spDCM',parc_dirname,masks_dirname);

pipeline        = 'tedanaGLM';

TR              = 0.91;      % repetition time
DCM_overwrite   = true;     % overwrite DCM file

% DCM specification

% create subject-specific DCM folder if not already existing
dir_out         = fullfile(dir_DCM,subj,ses);
if ~exist(dir_out,'dir'); mkdir(dir_out); end

DCM_name        = [subj,'_',ses,'_task-',task,'_run-',run_str,'_DCM.mat'];
file_DCM        = fullfile(dir_out,DCM_name);
if exist(file_DCM,'file')
    if DCM_overwrite
        % delete existing DCM file if DCM_overwrite = true
        delete(file_DCM)
    else
        % skip this task
        warning(['Skipped existing DCM: ',subj,' ',ses,' ',task])
        return
    end
end

% load time series
f_ts        = fullfile(dir_ts,subj,ses,['task-',task],...
    [subj,'_',ses,'_task-',task,'_run-',run_str,'_timeseries-',pipeline,'.mat']);
if exist(f_ts,'file')
    load(fullfile(f_ts),'time_series','ROI_names');
else
    error(['Skipped due to missing time series file: ',subj,' ',ses,' ',task])
end

n           = size(time_series,2);	% number of ROIs
v           = size(time_series,1);	% number of volumes
DCM.Y.y     = time_series;
DCM.name    = DCM_name;
for i = 1:n
    DCM.xY(i).name = ROI_names{i};
end
DCM.v       = v;
DCM.n       = n;    
DCM.Y.name  = ROI_names;
DCM.Y.dt    = TR; % repetition time
DCM.Y.X0    = zeros(v,1);
DCM.Y.Q     = spm_Ce(ones(1,n)*v);
DCM.delays  = repmat(DCM.Y.dt,DCM.n,1); % delays
DCM.U.u     = zeros(v,1);
DCM.U.name  = {'null'};

DCM.a       = ones(n,n);
DCM.b       = zeros(n,n,0);
DCM.c       = zeros(n,0);
DCM.d       = zeros(n,n,0);

DCM.options.stochastic  = 0;
DCM.options.nonlinear   = 0;
DCM.options.two_state   = 0;
DCM.options.analysis    = 'CSD'; % cross spectral densities
DCM.options.induced     = 1;
DCM.options.maxnodes    = n; % number of modes
DCM.options.maxit       = 256; % max number of iterations
DCM.options.nograph     = 1; % turn off graphical display

disp(DCM)

save(file_DCM,'DCM');

% DCM estimation
disp(['Estimating: ',file_DCM])
tic
spm_dcm_fmri_csd(file_DCM); 
tEnd = datenum(0,0,0,0,0,toc); % time since previous 'tic'
fprintf('Elapsed time is %s\n', datestr(tEnd,'HH:MM:SS'))

end

