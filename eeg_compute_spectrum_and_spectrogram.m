% ------------------------------------------------------------------------%
% EEG data: FFT and Time-Frequency Analyses
% ------------------------------------------------------------------------%
% 1) Load EEG data, convert to Fieldtrip format, save
% 2) Convert the data from the time domain to the frequency domain via a
%    Fast Fourier Transform (FFT), Create Grand Average (GA) files for each 
%    dataset (required for statistical analyses), save the outputs
% 3) Compute time-frequency spectrogram and grand average
% ------------------------------------------------------------------------%

clear;

%% 1. Path & Parameter Configuration
% MODIFY THESE PATHS FOR YOUR LOCAL SYSTEM
ROOT_DIR     = "/path/to/PsiConnect/folder"; 
FT_PATH      = "/path/to/fieldtrip-toolbox";

% Setup environment
addpath(FT_PATH);
ft_defaults;

% Define data directories based on the root path
dir_clean    = fullfile(ROOT_DIR, "derivatives", "EEG", "cleaned_RELAX");
dir_FT       = fullfile(dir_clean, "FieldTrip_format");

taskorder    = ["movie", "rest", "meditation", "music"];
sessions     = ["01", "02"];    

% Pattern of specific subjects/sessions to exclude due to artifacts or missing data
exclude      = ["sub-PC011", "sub-PC016", "sub-PC024", "sub-PC212", ...
                "sub-PC215", "sub-PC231", "sub-PC232", "sub-PC202", "sub-PC203", ...
                "sub-PC008_ses-01_task-movie", "sub-PC008_ses-02_task-movie", ...
                "sub-PC033_ses-01_task-movie", "sub-PC033_ses-02_task-movie", ...
                "sub-PC201_ses-01_task-movie", "sub-PC201_ses-02_task-movie"];

%% 2. Convert EEGLAB (.set) to FieldTrip Format
dir_in  = dir_clean;
dir_out = dir_FT;

if ~exist(dir_out, "dir"), mkdir(dir_out); end

for ses = sessions
    disp("Processing Session: " + ses)
    for task = taskorder
        disp("Processing Task: " + task)

        % Find all clean EEGLAB files for this session and task
        f_list = dir(fullfile(dir_clean, "**", "*ses-" + ses + "_task-" + task + "*_Clean.set"));
    
        for i = 1:length(f_list)
            f_in = f_list(i).name;
            % FIX: Corrected pop_loadset key-value pair format
            EEG = pop_loadset('filename', f_in, 'filepath', dir_in);
    
            EEG.group = 1;
            if strcmp(ses, "01")
                EEG.condition = 1;
            elseif strcmp(ses, "02")
                EEG.condition = 2;
            end
    
            % Convert structure to FieldTrip format
            ftData = eeglab2fieldtrip(EEG, 'preprocessing');
    
            % Save output
            f_out = f_in(1:end-4) + "-ft.mat";
            save(fullfile(dir_out, f_out), "ftData");
        end
    end
end

%% 3. Fourier Transform (FFT Power Spectrum via Welch's Method)
dir_in  = dir_FT;
dir_out = fullfile(dir_FT, "FFT");

if ~exist(dir_out, "dir"), mkdir(dir_out); end

for ses = sessions
    disp("FFT Session: " + ses)
    for task = taskorder
        disp("FFT Task: " + task)

        f_names = dir(fullfile(dir_in, "*ses-" + ses + "_task-" + task + "*_Clean-ft.mat"));
        f_names = {f_names.name};
        f_names(contains(f_names, exclude)) = []; % Excluded subjects/sessions
    
        FourierOut_all = cell(length(f_names), 1);
        for i_file = 1:length(f_names)
            ftData = [];
            f_in = f_names{i_file};
            load(fullfile(dir_in, f_in));
    
            % Segment data using a sliding window strategy (Welch's approximation)
            cfg         = [];
            cfg.length  = 2;   % Segment length in seconds
            cfg.overlap = 0.5; % 50% overlap
            data_segmented = ft_redefinetrial(cfg, ftData);
    
            % Run FFT frequency analysis
            cfg            = [];
            cfg.channel    = {'all'};
            cfg.method     = 'mtmfft';
            cfg.output     = 'pow';
            cfg.taper      = 'hanning';
            cfg.keeptrials = 'no';
            cfg.foi        = 1:45; % Frequency spectrum from 1 to 45 Hz
            
            FourierOut = ft_freqanalysis(cfg, data_segmented);
            FourierOut_all{i_file} = FourierOut;
                
            f_out = f_in(1:end-4) + "-FFT.mat";
            save(fullfile(dir_out, f_out), "FourierOut");
        end
    
        % Compute and save Grand Average across all valid participants
        cfg = [];
        cfg.keepindividual = 'yes';
        grandAverage = ft_freqgrandaverage(cfg, FourierOut_all{:});
        f_out = "ses-" + ses + "_task-" + task + "_Clean-ft-FFT-GA.mat";
        save(fullfile(dir_out, f_out), "grandAverage");
    end
end

%% 4. Cross-spectral density Analysis
dir_in  = dir_FT;
dir_out = fullfile(dir_FT, "CSD");

if ~exist(dir_out, "dir"), mkdir(dir_out); end

for ses = sessions
    disp("CSD Session: " + ses)
    for task = taskorder
        disp("CSD Task: " + task)

        f_names = dir(fullfile(dir_in, "*ses-" + ses + "_task-" + task + "*_Clean-ft.mat"));
        f_names = {f_names.name};
        f_names(contains(f_names, exclude)) = [];
    
        CSD_all = cell(length(f_names), 1);
        for i_file = 1:length(f_names)
            ftData = [];
            f_in = f_names{i_file};
            load(fullfile(dir_in, f_in));
    
            cfg         = [];
            cfg.length  = 2; % Segment length in seconds
            cfg.overlap = 0.5; % 50% overlap
            data_segmented = ft_redefinetrial(cfg, ftData);
    
            cfg            = [];
            cfg.channel    = {'all'};
            cfg.method     = 'mtmfft';
            cfg.output     = 'powandcsd'; % Compute both cross-spectral density and power
            cfg.taper      = 'hanning';
            cfg.keeptrials = 'no';
            cfg.foi        = 1:45;
            
            CSD = ft_freqanalysis(cfg, data_segmented);
            CSD_all{i_file} = CSD;
                
            f_out = f_in(1:end-4) + "-CSD.mat";
            save(fullfile(dir_out, f_out), "CSD");
        end
    
        cfg = [];
        cfg.keepindividual = 'yes';
        grandAverage = ft_freqgrandaverage(cfg, CSD_all{:});
        f_out = "ses-" + ses + "_task-" + task + "_Clean-ft-CSD-GA.mat";
        save(fullfile(dir_out, f_out), "grandAverage");
    end
end
