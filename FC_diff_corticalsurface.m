clear

%% ====== USER-CONFIGURABLE SETTINGS ======

% This script requires helper functions from this repository to be on the
% MATLAB path (plot_surface_fsLR_32k, bids_filenames_to_table, etc.).
addpath('/path/to/PsiConnect/scripts')

stringent_fd    = false;
GSR             = false; % global signal regression
FisherZ         = true; % compute Fisher z-transform of correlation values
plot_zscores    = false; % compute z-score of differences

dir_base        = '/path/to/PsiConnect';
dir_bids        = fullfile(dir_base,'bids');
dir_deriv       = fullfile(dir_base,'derivatives');
dir_phenotype   = fullfile(dir_base,'phenotype');

if GSR
    dir_FC      = fullfile(dir_deriv,"tedana-0.0.12-GLM-GSR");
else
    dir_FC      = fullfile(dir_deriv,"tedana-0.0.12-GLM");
end
dir_results     = fullfile('/path/to/results','FC','Global FC');
f_exclusions    = fullfile(dir_base,'participants_to_exclude_MRIqc.xlsx');

taskorder       = ["rest","meditation","music","movie"];

ignore_vols     = 5;

% cortical surface plots parameters
mesh            = "midthickness";
show_medial_wall = 1;

save_figs       = false;

%% load FC and compute GFC and eigenvectors for all subjects
if GSR
    f_FC_tab = fullfile(dir_results, "GFC_corticalsurface_table_GSR.mat");
else
    f_FC_tab = fullfile(dir_results, "GFC_corticalsurface_table.mat");
end
if isfile(f_FC_tab)
    load(f_FC_tab,"FC_tab")
else
    disp("GFC table not found, will compute anew...")
    pause(8)
    FC_tab  = bids_filenames_to_table(fullfile(dir_FC,"**/*32k*.mat"));
    % load each FC matrix and compute mean
    for i_p = 1:length(FC_tab.path)
        load(FC_tab.path(i_p),"data_dtseries");
        for hemi = ["lh","rh"]
            data                = data_dtseries.(hemi(1));
            data                = data(:,ignore_vols+1:end)';
            FC                  = corr(data);
            diag_idx            = logical(eye(size(FC,1)));
            FC(diag_idx)        = 0; % set diagonal to zero
            if FisherZ
                FC              = atanh(FC);
            end
            % replace inf with NaN
            FC(isinf(FC))       = NaN;
            col                = "GFC_" + hemi(1);
            FC_tab.(col)(i_p)  = {mean(FC,2,"omitnan")};
            % standard deviation
            STD                 = std(data,0,1);
            STD(isinf(STD))     = NaN;
            col                 = "std_" + hemi(1);
            FC_tab.(col)(i_p)   = {STD'};
        end
        fprintf("%.2f %%\n",100 * i_p / size(FC_tab,1))
    end
    save(f_FC_tab,"FC_tab")
end
clear FC STD V D col diag_idx i_p

%% exclude participants
exclusions      = readtable(f_exclusions,...
                    "ReadVariableNames",true,...%first row = column names
                    "TextType","string"...
                    );
FC_tab          = exclude_from_table(FC_tab,exclusions);

%% set colour map
cold            = [0,0,0.5;  0,0.5,1;  1,1,1];
hot             = [0.5,0,0;  1,0,0;    1,1,1];
interp_steps    = 128;
interp_samples  = [0,0.3,1];
cold            = interp1(interp_samples,cold,linspace(0,1,interp_steps)); 
hot             = interp1(1-interp_samples,hot,linspace(0,1,interp_steps));       
cmap            = [cold;hot];
cmap            = [0.6,0.6,0.6; cmap]; % add grey for medial wall
clear hot cold

%% set colorbars limits

% find colorbar limits
diff_all = [];
for i_task = 1:length(taskorder)
    task                = taskorder(i_task);
    split_tb{1}         = FC_tab((FC_tab.ses == "Baseline") & (FC_tab.task == task),:);
    split_tb{2}         = FC_tab((FC_tab.ses == "Administration") & (FC_tab.task == task),:);

    % % match subjects across groups
    split_tb            = match_subjects_across_groups(split_tb);

    for hemi = ["lh","rh"]
            col             = "GFC_" + hemi;
            diff            = compute_percentage_difference(split_tb,col,plot_zscores);
            %diff            = compute_difference(split_tb,col,plot_zscores);

            diff_all        = [diff_all,diff];
    end
end
low                     = prctile(diff_all(:),2.5)
high                    = prctile(diff_all(:),97.5)
c_max                   = max(abs(low),abs(high));
clims                   = [-c_max,c_max]

if plot_zscores
    clims = [-3.5,3.5]
end

%% GFC surface plot (Baseline vs Admin)

dir_out     = fullfile(dir_results,"GFC_admin_minus_baseline")
f_name      = "4tasks_" + "GFC_corticalsurface_" + "ses2ses1";

TFCE        = false; % threshold based on TFCE analysis
dir_TFCE    = fullfile('path/to/results','TFCE');

% set output directory for figures
if plot_zscores
    dir_out     = dir_out + "_zscored";
    dir_TFCE    = dir_TFCE + "_zscored";
    f_name      = f_name + "_zscored";    
end
if GSR
    dir_out     = dir_out + "_GSR"
    dir_TFCE    = dir_TFCE + "_GSR"
    f_name      = f_name + "_GSR";
end

if TFCE
    f_name      = f_name + "_TFCE_mask";
end

% create figure
fig             = figure;
fig.Color       = [1 1 1]; % RGB value for white is [1 1 1]
fig.Position    = [586 29 1200 870];
% create a 4x4 tiled plot with no padding and spacing
tl              = tiledlayout(4, 4, "Padding", "compact", "TileSpacing", "none");
axis off

for i_task = 1:length(taskorder)
    task                = taskorder(i_task);
    split_tb{1}         = FC_tab((FC_tab.ses == "Baseline") & (FC_tab.task == task),:);
    split_tb{2}         = FC_tab((FC_tab.ses == "Administration") & (FC_tab.task == task),:);
    
    % match subjects across groups
    split_tb            = match_subjects_across_groups(split_tb);
    
    for hemi = ["lh","rh"]
        % concatenate GFC vectors
        col            = "GFC_" + hemi;
        diff           = compute_percentage_difference(split_tb,col,plot_zscores);
        %diff           = compute_difference(split_tb,col,plot_zscores);

        if TFCE
            TFCE_mask = readmatrix(fullfile(dir_TFCE, "task-"+task, hemi+"_tfce_tstat_uncp_thresholded.csv"));
            diff = TFCE_mask;
            clims = [-1.4,1.4];
        end

        % plot
        patches = cell(2,1);
        [fig_temp,patches{1},patches{2}] = plot_surface_fsLR_32k(diff,hemi,mesh,show_medial_wall,clims);

        for i_patch = 1:2
            tile        = nexttile(tl);
            copyobj(patches{i_patch}, tile);
            % set up view angle
            if i_patch == 1
                view_angle = [-90 0];
            else
                view_angle = [90 0];
            end
            view(view_angle)
            material dull
            camlight('headlight')
            axis off
            tile.DataAspectRatio        = [1 1 1];
            %tile.DataAspectRatioMode    = 'manual';
            %tile.PlotBoxAspectRatioMode = 'auto';
            %tile.XLimMode               = 'auto';
            %tile.YLimMode               = 'auto';
            %tile.ZLimMode               = 'auto';
            % colour scale and map
            clim(clims)
            colormap(cmap)
        end
        close(fig_temp)
    end
end

% Add a small horizontal color bar at the bottom
clim(clims)
colormap(cmap)
if ~TFCE
    cbar = colorbar('Orientation', 'horizontal', 'Position', [0.425, 0.035, 0.2, 0.011], 'FontSize', 14);
    cbar.Label.String = 'Effect size';
end

% save
if save_figs    
    % MATLAB .fig format
    savefig(fig,fullfile(dir_out,f_name))
    % PNG
    exportgraphics(fig,fullfile(dir_out,f_name + ".png"),"ContentType","image","Resolution",300)
    % PDF
    exportgraphics(fig,fullfile(dir_out,f_name + ".pdf"),"ContentType","vector")
    % close figures
    close all
    beep()
end


%% individual subjects

% set output directory for figures
if plot_zscores
    dir_out     = fullfile(dir_results,"GFC_admin_minus_baseline_zscored")
else
    dir_out     = fullfile(dir_results,"GFC_admin_minus_baseline")
end
if GSR
    dir_out     = dir_out + "_GSR"
end
%dir_out         = fullfile(dir_out,"individual subjects");
if ~isfolder(dir_out)
    mkdir(dir_out)
end

% plot all in one figure (only one task and one side of one hemishpere)

f_name          = "GFC_corticalsurface_ses2ses1_rest_all_individuals_sorted_by_MEQ30"

task            = "rest"
hemi            = "lh"

% create figure
fig             = figure;
fig.Color       = [1 1 1];
fig.Position    = [653 29 642 870];
% create a tiled plot
tl              = tiledlayout("flow","Padding", "tight", "TileSpacing", "tight");
axis off

split_tb{1}      = FC_tab((FC_tab.ses == "Baseline") & (FC_tab.task == task),:);
split_tb{2}      = FC_tab((FC_tab.ses == "Administration") & (FC_tab.task == task),:);
split_tb{2}      = add_behav(split_tb{2},{'MEQ30_MEAN'},dir_bids,dir_phenotype);
% match subjects across groups
split_tb         = match_subjects_across_groups(split_tb);

% sort by MEQ30
[split_tb{2},idx_sort]  = sortrows(split_tb{2},"MEQ30_MEAN");
split_tb{1}             = split_tb{1}(idx_sort,:);

% concatenate GFC vectors
col                     = "GFC_" + hemi;
z1                      = cat(2,split_tb{1}.(col){:});
z2                      = cat(2,split_tb{2}.(col){:});
% replace inf with NaN
z1(isinf(z1))           = NaN;
z2(isinf(z2))           = NaN;
% remove columns that are all NaNs
z1(:,all(isnan(z1),1))  = [];
z2(:,all(isnan(z1),1))  = [];

diff                    = (z2 - z1) ./ abs(z1);
low                     = prctile(diff(:),5);
high                    = prctile(diff(:),95);
c_max                   = max(abs(low),abs(high));
clims                   = [-c_max,c_max]

for i_row = 1:height(split_tb{2})
    MEQ_value           = round(split_tb{2}.MEQ30_MEAN(i_row));
    [fig_temp,patch1]   = plot_surface_fsLR_32k(diff(:,i_row),hemi,mesh,show_medial_wall,clims);

    % fill next tile
    tile = nexttile(tl);
    copyobj(patch1, tile);
    view([-90 0])
    material dull
    camlight('headlight')
    axis off
    axis tight
    % colour scale and map
    clim(clims)
    colormap(cmap)
    title(MEQ_value)

    close(fig_temp)
end

% Add a small horizontal color bar at the bottom
clim(clims)
colormap(cmap)
colorbar('Orientation', 'horizontal', 'Position', [0.75, 0.04, 0.2, 0.011], 'FontSize', 14);

% save
if save_figs    
    % MATLAB .fig format
    savefig(fig,fullfile(dir_out,f_name))
    % PNG
    exportgraphics(fig,fullfile(dir_out,f_name + ".png"),"ContentType","image","Resolution",450)
    % PDF
    exportgraphics(fig,fullfile(dir_out,f_name + ".pdf"),"ContentType","vector")
    % close figures
    close all
    beep()
end
beep()


%%
function [diff,z1,z2] = compute_difference(split_tb,col,perform_zscore)
    z1              = cat(2,split_tb{1}.(col){:});
    z2              = cat(2,split_tb{2}.(col){:});
    % replace inf with NaN
    z1(isinf(z1))    = NaN;
    z2(isinf(z2))    = NaN;
    % remove columns that are all NaNs
    z1(:,all(isnan(z1),1)) = [];
    z2(:,all(isnan(z1),1)) = [];
    % compute differences
    diff            = mean(z2,2,"omitnan") - mean(z1,2,"omitnan");
    if perform_zscore
        diff        = zscore(diff);
    end
end

%%
function [diff,z1,z2] = compute_percentage_difference(split_tb,col,perform_zscore)
    z1              = cat(2,split_tb{1}.(col){:});
    z2              = cat(2,split_tb{2}.(col){:});
    % replace inf with NaN
    z1(isinf(z1))    = NaN;
    z2(isinf(z2))    = NaN;
    % remove columns that are all NaNs
    z1(:,all(isnan(z1),1)) = [];
    z2(:,all(isnan(z1),1)) = [];
    % compute percentage differences
    diff            = 100 * (mean(z2,2,"omitnan") - mean(z1,2,"omitnan")) ./ abs(squeeze(mean(z1,2,"omitnan"))); % diff as % of group 1
    if perform_zscore
        diff        = zscore(diff);
    end
end
