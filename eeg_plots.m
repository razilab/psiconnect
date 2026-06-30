%% path and parameters
ROOT_DIR    = "/path/to/PsiConnect/folder"; 
FT_PATH     = "/path/to/fieldtrip-toolbox";

addpath(FT_PATH);
ft_defaults;

dir_clean   = fullfile(ROOT_DIR, "derivatives", "EEG", "cleaned_RELAX", "FieldTrip_format");
f_layout    = fullfile(ROOT_DIR, "derivatives", "EEG", "1010_layout.mat");
dir_out_root= fullfile(ROOT_DIR, "results", "EEG");

taskorder   = ["rest","meditation","music","movie"];
task_n      = length(taskorder);
sessions    = ["01", "02"];

font_size   = 10;
colors      = get(groot,"defaultAxesColorOrder"); % MATLAB default colours

save_figs   = false;

% turn off tex interpreter for axes tick labels, titles, etc (so the
% underscore is not interpeterd as a subscript)
set(groot,"defaultAxesTickLabelInterpreter","none") % only tick labels
set(groot,"defaulttextinterpreter","none") % general for all text

%% for each condition, load average power spectrum across all participants

dir_in  = dir_clean;

GA      = struct();
GA_db   = struct();

for ses = sessions
    disp(ses)
    for task = taskorder
        disp(task)

        % Load GA files into workspace
        load(fullfile(dir_clean, "FFT", "ses-" + ses + "_task-" + task + "_Clean-ft-FFT-GA.mat"));
    
        % Convert to dB to better distinguish between low power values
        grandAverage_dB = grandAverage;
        grandAverage_dB.powspctrm = 10*log10(grandAverage.powspctrm);
    
        GA_db.("ses"+ses).(task) = grandAverage_dB;
        GA.("ses"+ses).(task) = grandAverage;
    end
end

% read EEG channel labels
ch_labels = upper(GA.ses01.rest.label);

%% for each condition, plot spectrum comparing baseline vs admin

plot_dB = false;
dir_out = fullfile(dir_out_root, "power_spectrum");
if ~exist(dir_out, "dir") && save_figs, mkdir(dir_out); end

if plot_dB
    f_out = "power_spectrum_dB_ses2ses1";
else
    f_out = "power_spectrum_ses2ses1";
end

fig = figure("color","w");
fig.Name = "EEG power spectrum";
fig.Position = [329 56 387 836];
t = tiledlayout(task_n,1,"TileSpacing","tight","Padding","tight");

for i_task = 1:task_n
    tile = nexttile;
    task = taskorder{i_task};

    cfg = [];
    if plot_dB
        cfg.ylim = [-20,10];
        cfg.xlim = [1,40];
    else
        cfg.ylim = [0,4.5];
        cfg.xlim = [1,25];
    end
    cfg.linewidth = 2.5; % Line thickness
    cfg.graphcolor = colors(1:2,:);
    cfg.figure = tile;
    if plot_dB
        ft_singleplotER(cfg,GA_db.("ses01").(task), GA_db.("ses02").(task));  % Fieldtrip plotting function for GA data
    else
        ft_singleplotER(cfg,GA.("ses01").(task), GA.("ses02").(task));
    end
    if plot_dB
        ylabel("Power (dB)");
    else
        ylabel("Power");
    end
    %title(cfg.channel);
    title(task)
    set(gca, "linewidth",1.5)                              % set axis line wideth
    set(gca, "Layer", "top")                             % Put axes in front of patch

    % Add shading to denote alpha range
    patch([8 12 12 8], [-50 -50 50 50], [0.8, 0.8, 0.8], "FaceAlpha", 0.25, "EdgeColor", "none");

    pbaspect([2 1 1]); %aspect ratio
    box off;

    if i_task == 1
        % Include a legend
        h = legend("Baseline", "Administration","Alpha band", "Location", "northeast");
        set(h,"FontSize",font_size-2);
        legend box off
    end
    if i_task == task_n
        xlabel("Frequency (Hz)");
    end
    set(gca,"FontSize",font_size);
end


if save_figs
    % MATLAB .fig
    savefig(fullfile(dir_out,f_out))
    % PDF
    exportgraphics(gcf,fullfile(dir_out,f_out + ".pdf"),"ContentType","vector")
    % PNG
    exportgraphics(gcf,fullfile(dir_out,f_out + ".png"),"ContentType","image","Resolution",300)
end



%% for each session, compare spectra from 4 conditions

plot_dB = false;
dir_out = fullfile(dir_out_root, "power_spectrum");
if ~exist(dir_out, "dir") && save_figs, mkdir(dir_out); end
if plot_dB
    f_out = "power_spectrum_dB_4tasks";
else
    f_out = "power_spectrum_4tasks";
end

fig = figure("color","w");
fig.Name = "EEG power spectrum";
fig.Position = [536 324 425 484];
t = tiledlayout(2,1,"TileSpacing","tight","Padding","tight");

for i_ses = 1:length(sessions)
    ses = sessions{i_ses};

    tile = nexttile;
    hold on

    for i_task = 1:task_n
        task = taskorder{i_task};

        cfg = [];
        if plot_dB
            cfg.ylim = [-20,10];
            cfg.xlim = [1,40];
        else
            cfg.ylim = [0,4.5];
            cfg.xlim = [1,25];
        end
        cfg.linewidth = 2.5;
        cfg.graphcolor = colors(i_task,:);
        cfg.figure = tile;
        if plot_dB
            ft_singleplotER(cfg,GA_db.("ses"+ses).(task));
        else
            ft_singleplotER(cfg,GA.("ses"+ses).(task));
        end
    end
    box off
    pbaspect([2 1 1]); % aspect ratio
    set(gca, "linewidth",1.5)
    set(gca, "Layer", "top") % Put axes in front of patch

    % Add shading to denote alpha range
    patch([8 12 12 8], [-50 -50 50 50], [0.8, 0.8, 0.8], "FaceAlpha", 0.25, "EdgeColor", "none");

    if ses == "01"
        title("Baseline")
    elseif ses == "02"
        title("Administration")
    end

    if plot_dB
        ylabel("Power (dB)");
    else
        ylabel("Power");
    end
    if i_ses == 1
        legend([taskorder,"alpha band"], "Location", "northeast", "FontSize", font_size-2);
        legend box off;
    end
    if i_ses == 2
        xlabel("Frequency (Hz)");
    end

    set(gca, "linewidth", 1.5, "FontSize", font_size);
end

if save_figs
    % MATLAB .fig
    savefig(fullfile(dir_out,f_out))
    % PDF
    exportgraphics(gcf,fullfile(dir_out,f_out + ".pdf"),"ContentType","vector")
    % PNG
    exportgraphics(gcf,fullfile(dir_out,f_out + ".png"),"ContentType","image","Resolution",300)
end

%% topoplots power difference (admin - baseline)
% plot power of each frequency band across the scalp

plot_dB         = true;

dir_out = fullfile(dir_out_root, "head_plots");
if ~exist(dir_out, "dir") && save_figs, mkdir(dir_out); end
if plot_dB
    f_out = "head_plot_power_dB_4tasks";
else
    f_out = "head_plot_power_4tasks";
end

freqBands       = ["Theta","Alpha","Beta","Gamma"];
freqBandsRanges = [4 7;8 12;13 30;30 80];
zlims           = [-0.5, 0.5 ; -3.5 3.5; -0.1 0.1; -0.03 0.03];

fig             = figure("color","w");
fig.Name        = "Power difference for each frequency band (administration - baseline)";
fig.Position    = [505 26 1036 873];
t               = tiledlayout(task_n,4+1,"TileSpacing","tight","Padding","tight");

for i_task = 1:task_n
    task = taskorder{i_task};

    % add text with task name to center of the tile
    tile = nexttile;
    axis(tile, 'off')  % Turn off axes
    xlim(tile, [0 1])  % Set limits
    ylim(tile, [0 1])
    % Capitalize first letter
    task_capitalised = task;
    task_capitalised(1) = upper(task_capitalised(1));
    text(tile, 0.5, 0.5, task_capitalised, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontWeight', 'bold');

    if plot_dB
        data1 = GA_db.("ses01").(task);
        data2 = GA_db.("ses02").(task);
    else
        data1 = GA.("ses01").(task);
        data2 = GA.("ses02").(task);
    end
    diff            = data1;
    diff.label      = upper(diff.label);
    diff.powspctrm  = data2.powspctrm - data1.powspctrm;

    cfg                 = [];
    cfg.zlim            = [-3,3];
    % cfg.marker         = '0ff';
    cfg.markersymbol    = 's';
    cfg.markersize      = 1;
    cfg.markercolor     = [0.3 0.3 0.3];
    cfg.colormap        = '*RdBu';
    cfg.layout          = f_layout;
    cfg.parameter       = 'powspctrm';
    %cfg.colorbar        = 'EastOutside';
    cfg.style           = 'straight_imsat'; %'both_imsat'
    cfg.comment         = 'no';
    cfg.interactive     = 'no';

    for freqToPlot = freqBands
        tile                = nexttile;

        freq_range          = freqBandsRanges(strcmp(freqBands,freqToPlot),:);
        power_range         = zlims(strcmp(freqBands,freqToPlot),:);

        cfg.xlim            = freq_range;
        cfg.figure          = tile;
        ft_topoplotTFR(cfg, diff);

        if i_task == 1
            title(freqToPlot)
        end
    end
end

% add horizontal color bar at the bottom
cbar = colorbar;
cbar.Layout.Tile = "east";

if save_figs
    % MATLAB .fig
    savefig(fullfile(dir_out,f_out))
    % PDF
    exportgraphics(gcf,fullfile(dir_out,f_out + ".pdf"),"ContentType","vector")
    % PNG
    exportgraphics(gcf,fullfile(dir_out,f_out + ".png"),"ContentType","image","Resolution",300)
end


%% topoplots LZ complexity difference (admin - baseline)
% plot LZ complexity across the scalp

dir_out         = fullfile(dir_out_root, "LZ_complexity");
if ~exist(dir_out, "dir") && save_figs, mkdir(dir_out); end
f_out           = "head_plot_LZ_complexity_diff";
f_LZ_tab        = fullfile(dir_out,"EEG_table_LZ_complexity.mat");

% if the table already exists, load it. Else, compute it
if isfile(f_LZ_tab)
    fprintf("Loading table from file:\n %s \n",f_LZ_tab)
    tab_LZ = load(f_LZ_tab,"tab").tab;
else
    error("LZ complexity table not found in: %s",f_LZ_tab)
end

fig             = figure("color","w");
fig.Name        = "LZ complexity difference (administration - baseline)";
fig.Position    = [507 83 1008 778];
t               = tiledlayout(task_n,1+1,"TileSpacing","tight","Padding","tight");

for i_task = 1:task_n
    task = taskorder{i_task};

    % add text with task name to center of the tile
    tile = nexttile;
    axis(tile, 'off')  % Turn off axes
    xlim(tile, [0 1])  % Set limits
    ylim(tile, [0 1])
    % Capitalize first letter
    task_capitalised = task;
    task_capitalised(1) = upper(task_capitalised(1));
    text(tile, 0.5, 0.5, task_capitalised, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontWeight', 'bold');

    tab_split{1}   = tab_LZ((tab_LZ.ses == "Baseline") & (tab_LZ.task == task),:);
    tab_split{2}   = tab_LZ((tab_LZ.ses == "Administration") & (tab_LZ.task == task),:);    
    % match subjects across groups
    tab_split   = match_subjects_across_groups(tab_split);

    % get LZ valuesfor all subjects
    x1      = tab_split{1}.LZ_complexity;
    x2      = tab_split{2}.LZ_complexity;
    L       = length(x1{1});
    % concatenate
    x1      = cat(2,x1{:});
    x2      = cat(2,x2{:});
    % normalise by length
    x1      = x1 ./ (L / log2(L));
    x2      = x2 ./ (L / log2(L));
    % compute difference
    clear diff
    diff.label          = ch_labels;

    diff.powspctrm      = x2 - x1;

    diff.dimord         = 'chan_subj';
    diff.freq           = [1];

    cfg                 = [];
    cfg.zlim            = [-65,65];
    % cfg.marker         = '0ff';
    cfg.markersymbol    = 's';
    cfg.markersize      = 1;
    cfg.markercolor     = [0.3 0.3 0.3];
    cfg.colormap        = '*RdBu';
    cfg.layout          = f_layout;
    cfg.parameter       = 'powspctrm';
    %cfg.colorbar        = 'EastOutside';
    cfg.style           = 'straight_imsat'; %'both_imsat'
    cfg.comment         = 'no';
    cfg.interactive     = 'no';

    tile                = nexttile;

    cfg.figure          = tile;
    ft_topoplotTFR(cfg, diff);
end

% add horizontal color bar at the bottom
cbar = colorbar;
cbar.Layout.Tile = "east";

if save_figs
    % MATLAB .fig
    savefig(fullfile(dir_out,f_out))
    % PDF
    exportgraphics(gcf,fullfile(dir_out,f_out + ".pdf"),"ContentType","vector")
    % PNG
    exportgraphics(gcf,fullfile(dir_out,f_out + ".png"),"ContentType","image","Resolution",300)
end
