clear

%% ====== USER-CONFIGURABLE SETTINGS ======

% This script requires helper functions from this repository to be on the
% MATLAB path (plot_surface_fsLR_32k, bids_filenames_to_table, etc.).
addpath('/path/to/PsiConnect/scripts')

GSR             = false; % global signal regression

dir_base        = '/path/to/PsiConnect';
dir_results     = fullfile('/path/to/results','FC','Global FC');
dir_masks       = fullfile(dir_base,'masks','7_networks');

taskorder       = ["rest","meditation","music","movie"];
task_n          = length(taskorder);
sessions        = ["Baseline","Administration"];
ses_n           = length(sessions);
colours         = ["#66AAD7","#E89775","#7BC73B","#8438C4"];
save_figs       = false;

%% load FC and compute mean FC and modularity for all subjects
if GSR
    f_FC_tab = fullfile(dir_results, "GFC_corticalsurface_table_GSR.mat");
else
    f_FC_tab = fullfile(dir_results, "GFC_corticalsurface_table.mat");
end
if isfile(f_FC_tab)
    load(f_FC_tab,"FC_tab")
else
    error("gfc_table_not_found: %s",f_FC_tab)
end

%% masks
f_masks = [
    fullfile(dir_masks,"Vis_fsLR_32k.mat");
    fullfile(dir_masks,"SomMot_fsLR_32k.mat");
    fullfile(dir_masks,"DorsAttn_fsLR_32k.mat");
    fullfile(dir_masks,"Limbic_fsLR_32k.mat");
    fullfile(dir_masks,"SalVentAttn_fsLR_32k.mat");
    fullfile(dir_masks,"Default_fsLR_32k.mat");
    fullfile(dir_masks,"Cont_fsLR_32k.mat");
    ];

clear masks
mask_n                  = length(f_masks);
mask_names              = strings(mask_n,1);
for i_mask = 1:mask_n
    [~,mask_name,~]     = fileparts(f_masks(i_mask));
    mask_names(i_mask)  = erase(mask_name,"_fsLR_32k");
    % load lh and rh hemi masks
    mask                = load(f_masks(i_mask)).data_dtseries;
    masks{i_mask}       = [mask.("lh") ; mask.("rh")];
    plot_surface_fsLR_32k(mask.("lh"),"lh","midthickness",1);
    plot_surface_fsLR_32k(mask.("rh"),"rh","midthickness",1);
end
clear mask mask_name



%% histograms for each session and mask

% set output dir and file name
dir_out = fullfile(dir_results,'histograms_7_networks');
if GSR
    dir_out = dir_out + "_GSR";
end
% file name
f_out       = "GFC_hist_7networks";
if GSR
    f_out   = f_out + "_GSR";
end

xlims       = [-0.04,0.13];
ylims       = [0,8];

fig                     = figure;
fig.Color               = [1 1 1];
fig.Position            = [21 106 1861 692];
% Create a tiled plot with no padding and spacing
tiledlayout(2, 7, "Padding", "none", "TileSpacing", "tight");

for i_ses = 1:ses_n
    ses                = sessions(i_ses);

    for i_mask = 1:mask_n
        nexttile
        mask            = masks{i_mask};
    
        hold on
        for i_task = 1:length(taskorder)
            task            = taskorder(i_task); 
       
            split_tb        = FC_tab((FC_tab.ses == ses) & (FC_tab.task == task),:);
    
            clear GFC_sub
            % concatenate GFC_sub vectors for both hemi
            GFC_sub         = cat(2,split_tb.("GFC_lh"){:});
            GFC_sub         = [GFC_sub;cat(2,split_tb.("GFC_rh"){:})];
            % replace inf with NaN
            GFC_sub(isinf(GFC_sub)) = NaN;
            % remove columns that are all NaNs
            GFC_sub(:,all(isnan(GFC_sub),1)) = [];
            % compute mean
            GFC            = mean(GFC_sub,2,"omitnan");
            GFC            = filter_by_mask(GFC,mask);
            GFC(GFC==0)    = NaN;
        
            histogram(GFC(:),"Normalization","pdf","DisplayName",task,...
                             "FaceColor",colours(i_task),"FaceAlpha",0.8)
            xlim(xlims)
            ylim(ylims)
        end
        % only add network names to top row plots
        if i_ses == 1
            title(mask_names{i_mask})
        end
        % only add legend to first session and first mask
        if i_ses == 1 && i_mask == 1
            legend("Location","NorthWest")
        end
        % hide Y axis
        ax = gca;
        ax.YAxis.Visible = "off";
    end
end
if save_figs
    savefig(fullfile(dir_out,f_out))
    exportgraphics(fig,fullfile(dir_out,f_out + ".pdf"),"ContentType","vector")
    exportgraphics(fig,fullfile(dir_out,f_out + ".png"),"ContentType","image","Resolution",300)
end


%% difference boxplots (comparing masks)

% set output dir and file name
dir_out     = fullfile(dir_results,'GFC_eyesclosed_vs_open');
f_out       = "GFC_eyesclosed_vs_open_boxplots";
if GSR
    dir_out = dir_out + "_GSR";
    f_out   = f_out + "_GSR";
end

spacing         = 0.6;
gap             = 2;
colours         = ["#0072BD","#D95319"];

fig             = figure;
fig.Name        = "GFC difference (eyes closed - eyes open)";
fig.Color       = [1 1 1];
fig.Position    = [680 374 636 394];
% Create a tiled plot with no padding and spacing
tiledlayout(1,mask_n, "Padding", "none", "TileSpacing","tight");

% store GFC for all ses, tasks, masks
GFC_all     = struct();
for i_ses = 1:ses_n
    ses                 = sessions(i_ses);
    for i_task = 1:length(taskorder)
        task            = taskorder(i_task); 
        split_tb{i_task}= FC_tab((FC_tab.ses == ses) & (FC_tab.task == task),:);
    end
    % match subjects across tasks
    split_tb            = match_subjects_across_groups(split_tb);

    for i_task = 1:length(taskorder)
        task                    = taskorder(i_task); 
        % concatenate GFC_sub vectors for both hemi
        clear GFC_sub
        GFC_sub                 = cat(2,split_tb{i_task}.("GFC_lh"){:});
        GFC_sub                 = [GFC_sub;cat(2,split_tb{i_task}.("GFC_rh"){:})];
        GFC_sub(isinf(GFC_sub)) = NaN; % replace inf with NaN
        
        for i_mask = 1:mask_n
            mask                    = masks{i_mask};
            mask_name               = mask_names{i_mask};
            % store to compute diff later
            GFC_sub_filt            = GFC_sub;
            mask_rep                = repmat(mask,1,size(GFC_sub,2));
            GFC_sub_filt(~mask_rep) = NaN;
            GFC_all.(mask_name).(ses).(task) = GFC_sub_filt;
        end
    end
end

% plot and compute stats
p_vals              = struct();
effect_sizes        = struct();
for i_mask = 1:mask_n
    mask_name       = mask_names{i_mask};
    diff            = cell(2,1);
    for i_ses = 1:ses_n
        ses         = sessions(i_ses);
        hold on
        diff{i_ses} = [];
        diff{i_ses} = [diff{i_ses};mean(GFC_all.(mask_name).(ses).("rest") - GFC_all.(mask_name).(ses).("movie"),2)];
        diff{i_ses} = [diff{i_ses};mean(GFC_all.(mask_name).(ses).("meditation") - GFC_all.(mask_name).(ses).("movie"),2)];
        diff{i_ses} = [diff{i_ses};mean(GFC_all.(mask_name).(ses).("music") - GFC_all.(mask_name).(ses).("movie"),2)];
        diff{i_ses} = diff{i_ses}(:);
    
        boxchart( spacing*(i_ses+(ses_n+gap)*(i_mask-1)) * ones(length(diff{i_ses}),1), diff{i_ses}, ...
            "BoxFaceColor",colours(i_ses),"MarkerStyle","none")
    end
    
    % perform statistical tests and add indicators
    p_thr           = 0.05 / ses_n; % Bonferroni correction
    for i_ses = 1:ses_n-1
        % effect size
        effect = meanEffectSize(diff{i_ses+1},diff{i_ses},"Paired",true,"Effect","robustcohen","ConfidenceIntervalType","none")
        effect_sizes.(mask_name).robustcohen = effect.Effect;
        effect = (mean(diff{i_ses+1},"all","omitmissing")-mean(diff{i_ses},"all","omitmissing"))./abs(mean(diff{i_ses},"all","omitmissing"))
        effect_sizes.(mask_name).percentage_diff = effect;
        
        [p, h] = ranksum(diff{i_ses}, diff{i_ses+1}, "tail","right");
        p_vals.(mask_name) = p;
        disp(p)
        if p < p_thr
            % add star and link for significant difference
            x1 = spacing*(i_ses + (ses_n+gap)*(i_mask-1));
            x2 = spacing*(i_ses + (ses_n+gap)*(i_mask-1) + 1);
            % exclude outliers
            y1 = diff{i_ses}(~isoutlier(diff{i_ses},"quartiles"));
            y2 = diff{i_ses+1}(~isoutlier(diff{i_ses+1},"quartiles"));
            y  = max([y1(:);y2(:)]) + 0.004;
            plot([x1, x2], [y, y], "k-","DisplayName","")
            text(mean([x1, x2]), y+0.00, "*", "HorizontalAlignment", "center", "VerticalAlignment", "bottom")
        end
    end
end

% style figure
legend(strrep(sessions,"Administration","Psilocybin"));
xticks(spacing*(1.5+(ses_n+gap)*(0:mask_n-1)))
xlabels = mask_names;
xticklabels(xlabels)
ylabel("GFC difference (eyes closed - eyes open)")
xlim(spacing*[0,(ses_n+gap)*mask_n])
box on

if save_figs
    % MATLAB .fig
    savefig(fullfile(dir_out,f_out))
    % PDF
    exportgraphics(fig,fullfile(dir_out,f_out + ".pdf"),"ContentType","vector")
    % PNG
    exportgraphics(fig,fullfile(dir_out,f_out + ".png"),"ContentType","image","Resolution",300)

    % save effect sizes and p-values
    save(fullfile(dir_out,f_out + "_effect_sizes.mat"),"effect_sizes")
    save(fullfile(dir_out,f_out + "_p_values.mat"),"p_vals")
end







%% histograms for each session (not masked)

% set output dir and file name
dir_out = fullfile(dir_results,'histograms_7_networks');
f_out = "GFC_hist";

if GSR
    dir_out = dir_out + "_GSR";
    f_out   = f_out + "_GSR";
end

xlims       = [-0.06,0.15];
ylims       = [0,30];

fig             = figure;

% set background color to white and resize
fig.Color               = [1 1 1];
fig.Position            = [751 190 504 556];
% Create a tiled plot with no padding and spacing
tiledlayout(2, 1, "Padding", "none", "TileSpacing","tight");

for i_ses = 1:ses_n
    nexttile
    hold on
    for i_task = 1:length(taskorder)
        task            = taskorder(i_task); 
   
        split_tb     = FC_tab((FC_tab.ses == sessions(i_ses)) & (FC_tab.task == task),:);
        
        clear GFC_sub
        % concatenate GFC_sub vectors for both hemi
        GFC_sub         = cat(2,split_tb.("GFC_lh"){:});
        GFC_sub         = [GFC_sub;cat(2,split_tb.("GFC_rh"){:})];
        % replace inf with NaN
        GFC_sub(isinf(GFC_sub)) = NaN;
        % remove columns that are all NaNs
        GFC_sub(:,all(isnan(GFC_sub),1)) = [];
        % compute mean
        GFC             = mean(GFC_sub,2,"omitnan");
        GFC(GFC==0)     = NaN;
    
        histogram(GFC(:),70,"Normalization","pdf","DisplayName",task,...
            "FaceColor",colours(i_task),"FaceAlpha",0.8)
        xlim(xlims)
        ylim(ylims)
    end
    if i_ses == 1
        legend("Location","NorthWest")
    end

    % hide Y axis
    ax = gca;
    ax.YAxis.Visible = "off";
end

if save_figs
    savefig(fullfile(dir_out,f_out))
    exportgraphics(gcf,fullfile(dir_out,f_out + ".pdf"),"ContentType","vector")
    exportgraphics(gcf,fullfile(dir_out,f_out + ".png"),"ContentType","image","Resolution",300)
end

%% difference boxplots (not masked)

% set output dir and file name
dir_out     = fullfile(dir_results,'GFC_eyesclosed_vs_open');
f_out       = "GFC_eyesclosed_vs_open_boxplot";
if GSR
    dir_out = dir_out + "_GSR";
    f_out   = f_out + "_GSR";
end

spacing         = 0.75;
colours         = ["#0072BD","#D95319"];

fig             = figure;
fig.Name        = "GFC difference (eyes closed - eyes open)";
fig.Color       = [1 1 1];
fig.Position    = [680 348 312 420];

% store GFC for all sessions and tasks
GFC_all     = struct();
for i_ses = 1:ses_n
    ses                 = sessions(i_ses);
    for i_task = 1:length(taskorder)
        task            = taskorder(i_task); 
        split_tb{i_task}= FC_tab((FC_tab.ses == ses) & (FC_tab.task == task),:);
    end
    % match subjects across tasks
    split_tb            = match_subjects_across_groups(split_tb);
    for i_task = 1:length(taskorder)
        task            = taskorder(i_task); 
        % concatenate GFC_sub vectors for both hemi
        clear GFC_sub
        GFC_sub         = cat(2,split_tb{i_task}.("GFC_lh"){:});
        GFC_sub         = [GFC_sub;cat(2,split_tb{i_task}.("GFC_rh"){:})];
        % replace inf with NaN
        GFC_sub(isinf(GFC_sub)) = NaN;
        % store to compute diff later
        GFC_all.(ses).(task)    = GFC_sub;
    end
end

% plot and compute stats
diff                = cell(2,1);
for i_ses = 1:ses_n
    ses  = sessions(i_ses);
    hold on

    diff{i_ses} = [];
    diff{i_ses} = [diff{i_ses};mean(GFC_all.(ses).("rest") - GFC_all.(ses).("movie"),2)];
    diff{i_ses} = [diff{i_ses};mean(GFC_all.(ses).("meditation") - GFC_all.(ses).("movie"),2)];
    diff{i_ses} = [diff{i_ses};mean(GFC_all.(ses).("music") - GFC_all.(ses).("movie"),2)];
    diff{i_ses} = diff{i_ses}(:);

    boxchart(spacing*i_ses*ones(length(diff{i_ses}),1),diff{i_ses},"BoxFaceColor",colours(i_ses),"MarkerStyle","none")
end

% perform statistical tests and add indicators
clear p_vals effect_sizes
p_thr = 0.05 / ses_n; % Bonferroni correction
for i_ses = 1:ses_n-1
    % effect size
    effect = meanEffectSize(diff{i_ses+1},diff{i_ses},"Paired",true,"Effect","robustcohen","ConfidenceIntervalType","none")
    effect_sizes.robustcohen = effect.Effect;
    effect = (mean(diff{i_ses+1},"all","omitmissing")-mean(diff{i_ses},"all","omitmissing"))./abs(mean(diff{i_ses},"all","omitmissing"))
    effect_sizes.percentage_diff = effect;
        
    [p, h] = ranksum(diff{i_ses}, diff{i_ses+1}, "tail","right");
    p_vals = p;
    disp(p)
    if p < p_thr
        % add star and link for significant difference
        x1 = spacing*i_ses;
        x2 = spacing*(i_ses+1);
        y = max([diff{i_ses}; diff{i_ses+1}]) + 0.005;
        plot([x1, x2], [y, y], "k-","DisplayName","")
        text(mean([x1, x2]), y+0.00, "*", "HorizontalAlignment", "center", "VerticalAlignment", "bottom")
    end
end

% style figure
xticks(spacing*(1:ses_n))
xlabels = strrep(sessions,"Administration","Psilocybin");
xticklabels(xlabels)
ylabel("GFC difference (eyes closed - eyes open)")
xlim(spacing*[0,ses_n+1])
ylim([-0.03,0.09])
% draw box without ticks
ax = fig.CurrentAxes;
xline(ax.XLim(2),'-k','linewidth',ax.LineWidth)
yline(ax.YLim(2),'-k','linewidth',ax.LineWidth)

if save_figs
    % MATLAB .fig
    savefig(fullfile(dir_out,f_out))
    % PDF
    exportgraphics(gcf,fullfile(dir_out,f_out + ".pdf"),"ContentType","vector")
    % PNG
    exportgraphics(gcf,fullfile(dir_out,f_out + ".png"),"ContentType","image","Resolution",300)

    % save effect sizes and p-values
    save(fullfile(dir_out,f_out + "_effect_sizes.mat"),"effect_sizes")
    save(fullfile(dir_out,f_out + "_p_values.mat"),"p_vals")
end


%%
function map = filter_by_mask(map,mask)
    if isequal(size(map),size(mask))
        map(~logical(mask)) = 0;
    else
        disp("Map size:")
        disp(size(map))
        disp("Mask size:")
        disp(size(mask))
        error("The map and the mask have different sizes")
    end
end