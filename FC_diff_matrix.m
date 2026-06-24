clear

%% ====== USER-CONFIGURABLE SETTINGS ======

addpath('/path/to/spm12') % SPM12: https://www.fil.ion.ucl.ac.uk/spm/

% bluewhitered colormap — requires BrainEigenmodes:
% https://github.com/james-pang/BrainEigenmodes
addpath('/path/to/BrainEigenmodes/functions_matlab')

% modularity() requires the Brain Connectivity Toolbox (BCT):
% https://sites.google.com/site/bctnet/
addpath('/path/to/BCT')

% parcellation and mask settings
masks_dirname   = "332_ROIs";
parc_dirname    = "Schaefer2018_300Parcels_Tian_Subcortex";
f_parc_labels   = "Schaefer2018_300Parcels_Tian_Subcortex_order.txt";
network_names   = ["Sub";"Vis";"SomMot";"DorsAttn";"Limbic";"SalVentAttn";"Default";"Cont"];
% network_names   = ["sub";"vis";"smn";"lim";"snvan";"dmn";"cen"];

network_names   = lower(string(network_names)); % lowercase
networks_n      = length(network_names);

dir_base        = "/path/to/PsiConnect";
dir_deriv       = fullfile(dir_base,"derivatives");
dir_ts          = fullfile(dir_deriv,"timeseries",parc_dirname,masks_dirname); % time series
dir_parc        = fullfile(dir_deriv,"parcellations",parc_dirname);
dir_out         = fullfile("/path/to/results","FC",parc_dirname);
f_exclusions    = fullfile(dir_base,"participants_to_exclude_MRIqc.xlsx");

dir_bids        = fullfile(dir_base,"bids");
dir_phenotype   = fullfile(dir_base,"phenotype");

taskorder       = ["rest","meditation","music","movie"];
task_n          = length(taskorder);

FisherZ         = false; % compute Fisher z-transform of correlation values

save_figs       = false;

%% read parcellation

% load parcellation labels
temp            = readtable(fullfile(dir_parc,f_parc_labels),"Delimiter","tab");
parc_labels     = lower(string(temp.Var2)); % TODO using Var2 is not robust
% sort parcel indices by network
idx_sort    = [];
ticks_first = [0.5];
for i = 1:length(network_names)
    idx         = find(contains(parc_labels,network_names(i)));
    idx_sort    = [idx_sort ; idx];
    ticks_first = [ticks_first ; ticks_first(end) + length(idx)];
end
clear idx
parc_labels     = parc_labels(idx_sort);
ticks_mid       = ticks_first(1:end-1) - 1 + ...
    round((ticks_first(2:end) - ticks_first(1:end-1)) / 2); % -1

% community assignments
modules         = zeros(size(parc_labels));
for i = 1:length(network_names)
    idx         = contains(parc_labels,network_names(i));
    modules     = modules + i*idx;
end
clear idx

%% load time series and compute FC and modularity for all subjects

% load files and create table with one row per task
FC_tab          = bids_filenames_to_table(fullfile(dir_ts,"**/*timeseries*.mat"));

% load each FC matrix and compute mean
for i_p = 1:size(FC_tab,1)
    disp(i_p/length(FC_tab.path))
    %FC                  = load(FC_tab.path(i_p),"FC").FC(idx_sort,idx_sort);
    ts                  = load(FC_tab.path(i_p),"time_series").time_series(:,idx_sort);
    %FC_tab.timeseries(i_p)   = {ts'}; % large memory required
    [FC,p]              = corr(ts);
    diag                = logical(eye(size(FC,1)));
    FC(diag)            = 0; % set diagonal to zero
    if FisherZ
        FC              = atanh(FC);
    end
    % replace inf with NaN
    FC(isinf(FC))       = NaN;
    FC_tab.FC_mat(i_p)  = {FC};
    FC_tab.FC_mean(i_p) = mean(FC,"all");
    FC_tab.GFC(i_p)     = {mean(FC,1)};
    FC_tab.FC_mod(i_p)  = modularity(FC,[],modules,'negative_sym');
end

%% exclude participants
exclusions      = readtable(f_exclusions,...
                    "ReadVariableNames",true,...%first row = column names
                    "TextType","string"...
                    );
FC_tab          = exclude_from_table(FC_tab,exclusions);


%% plot mean FC matrices difference (Admin minus baseline)

f_out           = "FC_matrices_diff";

line_ticks      = ticks_first; %ticks_first(7:8);
line_style      = "-";
line_color      = [.7,.7,.7];
line_width      = 0.8;

load("jet_white_colormap.mat")

fig             = figure();
set(fig, "NumberTitle","off","Name", "FC");
fig.Position    = [677 26 339 837];
spacing         = 8;
tl              = tiledlayout(1+spacing*task_n,spacing*1, "TileSpacing", "tight", "Padding", "tight");

nexttile([1,spacing]);
%title("Psilocybin - No-Psilocybin");%, 'FontSize', 10);
axis off;

for i_task = 1:task_n
    task = taskorder(i_task);

    FC_all{1} = cat(3,FC_tab((FC_tab.ses == "Baseline") & (FC_tab.task == task),:).FC_mat{:});
    FC_all{2} = cat(3,FC_tab((FC_tab.ses == "Administration") & (FC_tab.task == task),:).FC_mat{:});

    ax(1) = nexttile([spacing,spacing]);
    imagesc(mean(FC_all{2},3) - mean(FC_all{1},3))
    %title(taskorder(i_task))
    clim([-1.2,1.2])
    %colormap(jet_white_colormap)
    colormap(bluewhitered)
    colorbar
    pbaspect([1,1,1])
    yticks(ticks_mid)
    yticklabels(network_names)
    xticks(ticks_mid)
    if i_task == task_n
        xticklabels(network_names)
        xtickangle(90)
    else
        xticklabels([])
    end
    set(gca,"TickLength",[0 0]) % hide ticks but keep labels
    % add custom grid lines
    arrayfun(@(x)xline(x,line_style,"Color",line_color,"LineWidth",line_width),line_ticks)
    arrayfun(@(x)yline(x,line_style,"Color",line_color,"LineWidth",line_width),line_ticks)
    
    %ax.FontSize = 11;
end

% % Add a small horizontal color bar at the bottom
% xlabel({' ';' '})
% cbar = colorbar('Orientation', 'horizontal', 'Position', [0.4, 0.035, 0.5, 0.011], 'FontSize', 14);

if save_figs
    % MATLAB .fig
    savefig(fullfile(dir_out,f_out))
    % PDF
    exportgraphics(gcf,fullfile(dir_out,f_out + ".pdf"),"ContentType","vector")
    % PNG
    exportgraphics(gcf,fullfile(dir_out,f_out + ".png"),"ContentType","image","Resolution",300)
end


%% modularity boxplots (administration vs baseline)

spacing = 6;

figure
hold on
markersize = 16;


FC_all{1}   = FC_tab((FC_tab.ses == "Baseline"),:);
FC_all{2}   = FC_tab((FC_tab.ses == "Administration"),:);
% match subjects across groups
FC_all      = match_subjects_across_groups(FC_all);

% baseline
boxchart(spacing*(double(FC_all{1}.task))-5,FC_all{1}.FC_mod,"BoxFaceColor","#0072BD","MarkerStyle","none")
swarmchart(spacing*(double(FC_all{1}.task))-4,FC_all{1}.FC_mod,markersize,"o","filled","MarkerFaceColor","#0072BD","MarkerFaceAlpha",0.5,"MarkerEdgeAlpha",0.5,"XJitterWidth",1.0)
% admin
boxchart(spacing*(double(FC_all{2}.task))-3,FC_all{2}.FC_mod,"BoxFaceColor","#D95319","MarkerStyle","none")
swarmchart(spacing*(double(FC_all{2}.task))-2,FC_all{2}.FC_mod,markersize,"o","filled","MarkerFaceColor","#D95319","MarkerFaceAlpha",0.5,"MarkerEdgeAlpha",0.5,"XJitterWidth",1.0)

xticks(spacing*[1,2,3,4]-3.5)
xlim([0,23])
labels = string(FC_all{1}.task(1:task_n));
labels = labels(double(FC_all{1}.task(1:task_n)));
labels = labels(double(FC_all{1}.task(1:task_n)));
xticklabels(labels)
% medians   = groupsummary(FC_tab,["ses","task"],"median","FC_mod");
% plot(spacing*[1,2,3,4]-5,medians(medians.ses == "Baseline",:).median_FC_mod, ...
%     "-o","Color","#0072BD","DisplayName","Median (Baseline)")
% plot(spacing*[1,2,3,4]-3,medians(medians.ses == "Administration",:).median_FC_mod, ...
%     "-o","Color","#D95319","DisplayName","Median (Psilocybin)")
ylim([-0.005,0.21])
ylabel("FC Modularity")

% perform statistical tests and add indicators
p_thr = 0.05 / task_n; % Bonferroni correction
clear p_vals effect_sizes
for i_task = 1:task_n
    task            = taskorder(i_task)
    clear FC_all

    FC_all{1}       = FC_tab((FC_tab.ses == "Baseline") & (FC_tab.task == task),:);
    FC_all{2}       = FC_tab((FC_tab.ses == "Administration") & (FC_tab.task == task),:);
    % match subjects across groups
    FC_all          = match_subjects_across_groups(FC_all);
    % read modularity
    baseline_data   = FC_all{1}.FC_mod;
    admin_data      = FC_all{2}.FC_mod;

    % effect size
    effect = meanEffectSize(admin_data,baseline_data,"Paired",true,"Effect","robustcohen","ConfidenceIntervalType","none")
    effect_sizes.(task).robustcohen = effect.Effect;
    effect = (mean(admin_data,"all","omitmissing")-mean(baseline_data,"all","omitmissing"))./abs(mean(baseline_data,"all","omitmissing"))
    effect_sizes.(task).percentage_diff = effect;
    
    [p, h] = ranksum(baseline_data, admin_data, "tail","right");
    p_vals.(task) = p;
    disp(p)

    if p < p_thr
        % add star and link for significant difference
        x1 = spacing*i_task - (spacing-1);
        x2 = spacing*i_task - (spacing-3);
        y = max([baseline_data; admin_data]) + 0.005;
        plot([x1, x2], [y, y], "k-","DisplayName","")
        text(mean([x1, x2]), y+0.00, "*", "HorizontalAlignment", "center", "VerticalAlignment", "bottom")
    end
end
legend(["No-Psilocybin","","Psilocybin",""],"Location","northwest")

if save_figs
    f_out = "swarmchart_FC_modularity";
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

%% modularity boxplots for meditators vs non-meditators (administration session only)
spacing = 6;

figure
hold on
markersize = 16;
temp    = FC_tab((FC_tab.ses == "Administration") & (FC_tab.group == "Non-Meditators"),:);
boxchart(spacing*(double(temp.task))-5,temp.FC_mod,"BoxFaceColor","#0072BD")
swarmchart(spacing*(double(temp.task))-4,temp.FC_mod,markersize,"o","filled","MarkerFaceColor","#0072BD","MarkerFaceAlpha",0.5,"MarkerEdgeAlpha",0.5,"XJitterWidth",1.0)
temp    = FC_tab((FC_tab.ses == "Administration") & (FC_tab.group == "Meditators"),:);
boxchart(spacing*(double(temp.task))-3,temp.FC_mod,"BoxFaceColor","#D95319")
swarmchart(spacing*(double(temp.task))-2,temp.FC_mod,markersize,"o","filled","MarkerFaceColor","#D95319","MarkerFaceAlpha",0.5,"MarkerEdgeAlpha",0.5,"XJitterWidth",1.0)
xticks(spacing*[1,2,3,4]-3.5)
xlim([0,23])
labels = string(temp.task(1:task_n));
labels = labels(double(temp.task(1:task_n)));
labels = labels(double(temp.task(1:task_n)));
xticklabels(labels)
ylim([-0.005,0.2])
ylabel("FC Modularity")
%ylim([-0.005,0.125])

clear p_vals effect_sizes

% perform statistical tests and add indicators
p_thr = 0.05 / task_n; % Bonferroni correction
for i_task = 1:task_n
    task            = taskorder(i_task)
    baseline_data   = FC_tab((FC_tab.ses == "Administration") & (FC_tab.group == "Non-Meditators") & (FC_tab.task == task),:).FC_mod;
    admin_data      = FC_tab((FC_tab.ses == "Administration") & (FC_tab.group == "Meditators") & (FC_tab.task == task),:).FC_mod;

    % effect size
    effect = meanEffectSize(admin_data,baseline_data,"Effect","robustcohen","ConfidenceIntervalType","none")
    effect_sizes.(task).robustcohen = effect.Effect;
    effect = (mean(admin_data,"all","omitmissing")-mean(baseline_data,"all","omitmissing"))./abs(mean(baseline_data,"all","omitmissing"))
    effect_sizes.(task).percentage_diff = effect;

    [p, ~] = ranksum(baseline_data, admin_data);
    p_vals.(task) = p;
    disp(length(baseline_data))
    disp(length(admin_data))
    disp(p)
    if p < p_thr
        % add star and link for significant difference
        x1 = spacing*i_task - (spacing-1);
        x2 = spacing*i_task - (spacing-3);
        y = max([baseline_data; admin_data]) + 0.005;
        plot([x1, x2], [y, y], "k-","DisplayName","")
        text(mean([x1, x2]), y+0.00, "*", "HorizontalAlignment", "center", "VerticalAlignment", "bottom")
    end
end
legend(["Non-Meditators","","Meditators",""])
%
if save_figs
    f_out = "swarmchart_FC_modularity_mednonmed";
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
