clear

% define paths
dir_base        = "/path/to/PsiConnect/folder"; 
dir_bids        = fullfile(dir_base,"bids");
dir_EEG         = fullfile(dir_base,"derivatives","EEG","cleaned_RELAX","FieldTrip_format");
dir_out         = fullfile(dir_base,"results","EEG","LZ_complexity");

taskorder       = ["movie","rest","meditation","music"];
tasks_n         = length(taskorder);
sessions        = ["Baseline", "Administration"];

%% compute LZ complexity
f_LZ_tab        = fullfile(dir_out,"EEG_table_LZ_complexity.mat");

    
% get table from file names
f_pattern   = fullfile(dir_EEG,"sub*Clean-ft.mat");
tab         = bids_filenames_to_table(f_pattern,true);

for i_row = 1:height(tab)
    disp(100*i_row/height(tab))

    % load time series
    load(tab.path(i_row),"ftData")
    ts                      = ftData.trial{1}';

    % binarise time series for LZ complexity calculation
    ts                      = int16(ts > mean(ts));
    channel_n               = size(ts,2);
    LZ                      = NaN(channel_n,1);
    tic
    parfor i_ch = 1:channel_n
        LZ(i_ch)            = LZ_complexity_1976(ts(:,i_ch));
    end
    toc
    tab.LZ_complexity(i_row)= {LZ};

    % save progress
    if mod(i_row,50) == 0 || i_row == height(tab)
        save(f_LZ_tab,"tab")
    end
end
