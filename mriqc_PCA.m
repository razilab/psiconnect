clear

% choose whether to analyse BOLD or T1 QC metrics
bold      = true; % true=BOLD, false=T1

font_size = 12;

%% import group file from MRIwc folder
if bold
    qc          = tdfread(fullfile(dir_mriqc,"group_bold.tsv"));
else
    qc          = tdfread(fullfile(dir_mriqc,"group_T1w.tsv"));
end

% split filenames into separate columns (one for each BIDS entity)
labels          = string(qc.bids_name);
temp            = split(labels,"_");
temp            = split(temp(:,1:end-1),"-"); % ignore last field, e.g. "_bold"
new_vars        = temp(1,:,1);
qc.bids_name    = temp(:,:,2);
qc              = struct2table(qc);
qc              = splitvars(qc,"bids_name","NewVariableNames",new_vars);
% convert selected fields from string to numeric format
qc.ses          = str2double(qc.ses);
 %qc.ses          = strrep(qc.ses,"01","Baseline");
 %qc.ses          = strrep(qc.ses,"02","Administration");
 %qc.ses          = categorical(qc.ses,["Baseline","Administration"],"Ordinal",true);
qc.run          = str2double(qc.run);
if bold
    qc.echo     = str2double(qc.echo);
    qc.task     = categorical(qc.task,["rest","meditation","music","movie"],'Ordinal',true);
end

% remove constant columns
qc.size_x       = [];
qc.size_y       = [];
qc.size_z       = [];
qc.spacing_x    = [];
qc.spacing_y    = [];
qc.spacing_z    = [];
if bold
    qc.spacing_tr   = [];
end

%% Framewise displacement comparison baseline vs admin
if bold
    group_by    = "ses";
    groups      = ["1";"2"];
    feature_of_interest = "fd_mean";
    qc_interest = qc.(feature_of_interest);
    fd1         = qc_interest(contains(string(qc.(group_by)),string(groups(1))));
    fd2         = qc_interest(contains(string(qc.(group_by)),string(groups(2))));

    qc_x        = double(qc.(group_by));
    x1          = qc_x(contains(string(qc.(group_by)),string(groups(1))));
    x2          = qc_x(contains(string(qc.(group_by)),string(groups(2))));

    
    % t-test and KS test
    [h,p]       = ttest2(fd1,fd2)
    [p,h]       = ranksum(fd1,fd2)
    [h,p]       = kstest2(fd1,fd2)
    
    % figure("Name",strcat(feature_of_interest," ",group_by," ",groups(1)," vs ",groups(2))');
    % histogram(fd1,20,"DisplayName",groups(1))
    % hold on
    % histogram(fd2,20,"DisplayName",groups(2))
    % xlabel(feature_of_interest,"Interpreter","none")
    % legend
    
    fig         = figure();
    fig.Name    = strcat(feature_of_interest," ",group_by," ",groups(1)," vs ",groups(2));
    fig.Color   = [1,1,1];
    fig.Position = [481 219 382 376];
    % boxplot([fd1;fd2],[repmat(groups(1),size(fd1));repmat(groups(2),size(fd2))])
    % %xlabel(group_by)
    % ylabel(feature_of_interest,"Interpreter","none")
    hold on
    swarmchart(x1*2-0.3,fd1,"o","filled","MarkerFaceColor","#0072BD",...
        "MarkerFaceAlpha",0.2,"MarkerEdgeAlpha",0.5,"XJitterWidth",0.5)
    swarmchart(x2*2-0.3,fd2,"o","filled","MarkerFaceColor","#D95319",...
        "MarkerFaceAlpha",0.2,"MarkerEdgeAlpha",0.5,"XJitterWidth",0.5)
    boxchart(x1*2-1,fd1,"BoxFaceColor","#0072BD","MarkerStyle","none")
    boxchart(x2*2-1,fd2,"BoxFaceColor","#D95319","MarkerStyle","none")
    xticks([1.4,3.4])
    xlim([0.5,4.1])

    %ylim([0,1.3])
    if max([fd1;fd2]) > 0.5
        yline(0.5,"--","Color",[0.8,0.8,0.8])
    end

    ylabel(strrep(feature_of_interest,"fd_mean","Head motion (mean FD)"))
    xticklabels(["No Psilocybin","Psilocybin"])
    
    
    ax = gca;
    ax.FontSize = font_size;
    ax.LineWidth = 1.5;
    
    axis square
    box on
end


%% Framewise displacement comparison across conditions
if bold
    group_by = "task";
    groups = ["rest","meditation","music","movie"];
    feature_of_interest = "fd_mean";

    % Prepare figure and layout
    fig = figure();
    fig.Color = [1,1,1];
    fig.Position = [200 200 1000 450];  % wider figure for two panels
    tl = tiledlayout(fig, 1, 2, "TileSpacing", "compact", "Padding", "compact");

    % Mapping session index to display name
    ses_names = ["Baseline","Psilocybin"];

    % Track ymax across subplots for consistent y-limits
    ymax_across = 0;
    ax_list = gobjects(1, numel(ses_names));

    for i_ses = 1:numel(ses_names)
        ses_to_plot = ses_names(i_ses);

        nexttile(tl, i_ses);
        ax = gca;
        ax_list(i_ses) = ax;

        x = [];
        y = [];
        ybar = NaN;

        % Reset fd_previous for this subplot
        fd_previous = [];

        for i_group = 1:length(groups)
            group = groups(i_group);
            fd = qc.fd_mean(qc.ses == i_ses & contains(string(qc.(group_by)), group));
            y = [y ; fd];
            x = [x ; repmat(i_group, size(fd))];

            if i_group > 1 && ~isempty(fd_previous)
                % t-test and nonparametric tests
                [~, p1] = ttest2(fd, fd_previous);
                [p2, ~] = ranksum(fd, fd_previous);
                [~, p3] = kstest2(fd, fd_previous);
                p_thr = 0.05 / (length(groups) - 1);

                p_min = min([p1, p2, p3]);
                if p_min < p_thr
                    % Determine direction based on mean difference
                    d_mean = mean(fd, "omitnan") - mean(fd_previous, "omitnan");
                    if d_mean > 0
                        dir_arrow = "↑";
                        dir_text  = "increase";
                    elseif d_mean < 0
                        dir_arrow = "↓";
                        dir_text  = "decrease";
                    else
                        dir_arrow = "↔";
                        dir_text  = "no change";
                    end

                    % Position the bar above the current data
                    ybar = max(y(:), [], "omitnan") * 1.05;
                    hold on
                    x1 = (i_group - 1) * 1.05;
                    x2 = i_group * 0.95;
                    plot([x1, x2], [ybar, ybar], "k-", "DisplayName", "");
                    % Asterisk plus arrow for direction
                    text(mean([x1, x2]), ybar + 0.00, "*" + " " + dir_arrow, ...
                        "HorizontalAlignment", "center", "VerticalAlignment", "bottom");

                    % Print a detailed line to the console
                    fprintf("%s: %s vs %s -> significant %s (Δmean=%+.3g, p_min=%.3g)\n", ...
                        ses_to_plot, string(group), string(groups(i_group-1)), dir_text, d_mean, p_min);
                end
            end

            fd_previous = fd;
        end

        boxplot(y, x);

        if i_ses == 1
            ylabel(strrep(feature_of_interest, "fd_mean", "Mean framewise displacement (FD)"));
        end
        xticklabels(groups);
        % title
        title_string = sprintf('%c) %s', 'a' + i_ses - 1, ses_to_plot);
        title_string = strrep(title_string,'Baseline','No Psilocybin');
        text(ax, 0.00, 1.05, title_string, 'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', 'FontWeight', 'bold')

        % Track y max for harmonized limits
        ymax_local = 0;
        if ~isempty(y) && any(isfinite(y))
            ymax_local = max(y(:), [], "omitnan");
        end
        if ~isnan(ybar)
            ymax_local = max(ymax_local, ybar * 1.05);
        end
        if ymax_local > ymax_across
            ymax_across = ymax_local;
        end
    end

    % Apply consistent y-limits across both panels
    if ~(isfinite(ymax_across) && ymax_across > 0)
        ymax_across = 1;
    end
    for i_ax = 1:numel(ax_list)
        axes(ax_list(i_ax));
        ylim([0, ymax_across * 1.025]);
    end

    % Overall title
    %title(tl, "Framewise Displacement by Condition");
end


%% 2D PCA of T1w
if ~bold
    marker_size = 60;

    [U,~,~]     = svd(zscore(table2array(removevars(qc,new_vars))),"econ");

    % customise tooltips for each point in the scatter plots
    DataTipRows = [...
        dataTipTextRow("sub",qc.sub),...
        dataTipTextRow("ses",qc.ses),...
        ];
    
    fig = figure("Name","PCA of MRIqc features");
    fig.Position = [680 323 512 445];
    fig.Color = [1,1,1];
    hold on

    % draw a square around outliers
    idx = [6,12,14,55,95,123];
    scatter(U(idx,1),U(idx,2),marker_size + 60,"black","s");

    colours = qc.ses; %contains(qc.scanner,"Philips"); % for BOLD
    for ses = 1:4
        idx = qc.ses == ses;
        s = scatter(U(idx,1),U(idx,2),marker_size,colours(idx),"filled","MarkerFaceAlpha",0.7);
        % customise tooltips for each point in the scatter plots
        DataTipRows = [...
            dataTipTextRow("sub",qc.sub(idx)),...
            dataTipTextRow("ses",qc.ses(idx)),...
            ];
        s.DataTipTemplate.DataTipRows = DataTipRows;
    end
    ylim([-0.23,0.29])
    xlim([-0.68,0.14])
    colormap("flag")
    box on
    %title("2D PCA Embedding")
    % dummy plots (it makes this plot match the size of the others)
    scatter(-10,-10,"filled","MarkerFaceAlpha",0);
    scatter(-10,-10,"filled","MarkerFaceAlpha",0);

    lgd                 = legend(["Outliers","No Psilocybin","Psilocybin"," "," "]);
    lgd.Location        = "southoutside";
    %lgd.Orientation     = "horizontal";
    lgd.Box             = false;
    lgd.NumColumns      = 1;
    %lgd.IconColumnWidth = 10;
    
    % figure("Name","PCA of MRIqc features");
    % colours = qc.ses; % for T1w
    % s = scatter3(U(:,1),U(:,2),U(:,3),15,colours,"filled");
    % s.DataTipTemplate.DataTipRows = DataTipRows;
    % title("3D PCA Embedding")

    xlabel("Principal component 1")
    ylabel("Principal component 2")
    
    axis square
    
    ax = gca;
    ax.FontSize = font_size;
    ax.LineWidth = 1.5;
end


%% 2D and 3D PCA (colour by echo)
if bold
    marker_size = 60;
    
    [U,~,~]     = svd(zscore(table2array(removevars(qc,new_vars))),"econ");

    fig             = figure("Name","PCA of MRIqc features");
    fig.Position    = [680 329 665 439];
    fig.Color       = [1,1,1];
    hold on

    % draw a square around scans with high head motion (mean FD)
    fd_thr  = 0.5;
    idx     = qc.fd_mean > fd_thr;
    scatter(U(idx,1),U(idx,2),marker_size + 60,"black","s");

    colours = qc.echo; %contains(qc.scanner,"Philips"); % for BOLD
    for echo = 1:4
        idx = qc.echo == echo;
        s = scatter(U(idx,1),U(idx,2),marker_size,colours(idx),"filled","MarkerFaceAlpha",0.7);
        % customise tooltips for each point in the scatter plots
        DataTipRows = [...
            dataTipTextRow("sub",qc.sub(idx)),...
            dataTipTextRow("ses",qc.ses(idx)),...
            dataTipTextRow("task",qc.task(idx)),...
            dataTipTextRow("echo",qc.echo(idx)),...
            dataTipTextRow("mean FD",qc.fd_mean(idx)),...
            ];
        s.DataTipTemplate.DataTipRows = DataTipRows;
    end
    xlim([-0.075,0.04])
    ylim([-0.055,0.15])
    %title("2D PCA Embedding")
    colormap("lines")
    box on
    
    lgd                 = legend(["Large head motion","Echos: 1","2","3","4"]);
    lgd.Location        = "southoutside";
    %lgd.Orientation     = "horizontal";
    lgd.Box             = false;
    lgd.NumColumns      = 1;
    %lgd.IconColumnWidth = 10;
    
    % 3D
    % figure("Name","PCA of MRIqc features");
    % colours = 2*(qc.echo-1)+qc.ses; % for BOLD
    % colours = qc.fd_mean; % for BOLD
    % s = scatter3(U(:,1),U(:,2),U(:,3),15,colours,"filled");
    % s.DataTipTemplate.DataTipRows = DataTipRows;
    % title("3D PCA Embedding")

    xlabel("Principal component 1")
    ylabel("Principal component 2")
    
    axis square
    
    ax               = gca;
    ax.XAxisLocation = "top";
    ax.FontSize      = font_size;
    ax.LineWidth     = 1.5;
end

%% same but colour by task
if bold
    marker_size = 60;
    
    [U,~,~]     = svd(zscore(table2array(removevars(qc,new_vars))),"econ");

    fig             = figure("Name","PCA of MRIqc features");
    fig.Position    = [680 329 665 439];
    fig.Color       = [1,1,1];
    hold on

    % draw a square around scans with high head motion (mean FD)
    fd_thr  = 0.5;
    idx     = qc.fd_mean > fd_thr;
    scatter(U(idx,1),U(idx,2),marker_size + 60,"black","s");

    colours = double(qc.task);
    for task = 1:4
        idx = double(qc.task) == task;
        s = scatter(U(idx,1),U(idx,2),marker_size,colours(idx),"filled","MarkerFaceAlpha",0.7);
        % customise tooltips for each point in the scatter plots
        DataTipRows = [...
            dataTipTextRow("sub",qc.sub(idx)),...
            dataTipTextRow("ses",qc.ses(idx)),...
            dataTipTextRow("task",qc.task(idx)),...
            dataTipTextRow("echo",qc.echo(idx)),...
            dataTipTextRow("mean FD",qc.fd_mean(idx)),...
            ];
        s.DataTipTemplate.DataTipRows = DataTipRows;
    end
    xlim([-0.075,0.04])
    ylim([-0.055,0.15])
    %title("2D PCA Embedding")
    colormap("lines")
    box on
    
    lgd                 = legend(["Large head motion","Rest","Meditation","Music","Movie"]);
    lgd.Location        = "southoutside";
    %lgd.Orientation     = "horizontal";
    lgd.Box             = false;
    lgd.NumColumns      = 1;
    %lgd.IconColumnWidth = 10;

    xlabel("Principal component 1")
    ylabel("Principal component 2")
    
    axis square
    
    ax               = gca;
    ax.XAxisLocation = "top";
    ax.FontSize      = font_size;
    ax.LineWidth     = 1.5;
end

%% same but colour by session
if bold
    marker_size = 60;
    
    [U,~,~]     = svd(zscore(table2array(removevars(qc,new_vars))),"econ");

    fig             = figure("Name","PCA of MRIqc features");
    fig.Position    = [680 329 665 439];
    fig.Color       = [1,1,1];
    hold on

    % draw a square around scans with high head motion (mean FD)
    fd_thr  = 0.5;
    idx     = qc.fd_mean > fd_thr;
    scatter(U(idx,1),U(idx,2),marker_size + 60,"black","s");

    colours = 2-double(qc.ses);
    for ses = 2:-1:1
        idx = qc.ses == ses;
        s = scatter(U(idx,1),U(idx,2),marker_size,colours(idx),"filled","MarkerFaceAlpha",0.7);
        % customise tooltips for each point in the scatter plots
        DataTipRows = [...
            dataTipTextRow("sub",qc.sub(idx)),...
            dataTipTextRow("ses",qc.ses(idx)),...
            dataTipTextRow("task",qc.task(idx)),...
            dataTipTextRow("echo",qc.echo(idx)),...
            dataTipTextRow("mean FD",qc.fd_mean(idx)),...
            ];
        s.DataTipTemplate.DataTipRows = DataTipRows;
    end
    xlim([-0.075,0.04])
    ylim([-0.055,0.15])
    %title("2D PCA Embedding")
    colormap("lines")
    box on

    % dummy plots (it makes this plot match the size of the others)
    scatter(-10,-10,"filled","MarkerFaceAlpha",0);
    scatter(-10,-10,"filled","MarkerFaceAlpha",0);

    lgd                 = legend(["Large head motion","Psilocybin","No Psilocybin"," "," "]);
    lgd.Location        = "southoutside";
    %lgd.Orientation     = "horizontal";
    lgd.Box             = false;
    lgd.NumColumns      = 1;
    %lgd.IconColumnWidth = 10;

    xlabel("Principal component 1")
    ylabel("Principal component 2")
    
    axis square
    
    ax               = gca;
    ax.XAxisLocation = "top";
    ax.FontSize      = font_size;
    ax.LineWidth     = 1.5;
end

%% plot which feature loads the most on PC1 and PC2

% turn off tex interpreter for axes tick labels, titles, etc (so the
% underscore is not interpeterd as a subscript)
set(groot,"defaultAxesTickLabelInterpreter","none") % only tick labels
set(groot,"defaulttextinterpreter","none") % general for all text

qc_reduced  = removevars(qc,new_vars);

[U,~,V]     = svd(zscore(table2array(removevars(qc,new_vars))),"econ");

% Get the loadings of the first and second principal components
loadings_pc1 = V(:,1);
loadings_pc2 = V(:,2);

% Create tables for the loadings and sort each independently
loadings_table_pc1 = table(qc_reduced.Properties.VariableNames', loadings_pc1, 'VariableNames', {'Variable', 'Loading'});
loadings_table_pc1 = sortrows(loadings_table_pc1, 'Loading', 'descend');

loadings_table_pc2 = table(qc_reduced.Properties.VariableNames', loadings_pc2, 'VariableNames', {'Variable', 'Loading'});
loadings_table_pc2 = sortrows(loadings_table_pc2, 'Loading', 'descend');

% Create a tiled layout and plot the loadings on PC1 and PC2 in two subplots
fig             = figure("Name","PCA of MRIqc features");
fig.Position    = [475 26 1243 787];
fig.Color       = [1,1,1];
t               = tiledlayout(1,2);

% Plot loadings on PC1
nexttile;
barh(categorical(loadings_table_pc1.Variable, loadings_table_pc1.Variable), loadings_table_pc1.Loading,"FontSize",font_size);
ylabel('Features');
%xlabel('Loadings on PC1');
title('Feature Loadings on 1st Principal Component');
ax              = gca;
ax.YDir         = 'reverse';
ax.LineWidth    = 1.3;

% Plot loadings on PC2
nexttile;
barh(categorical(loadings_table_pc2.Variable, loadings_table_pc2.Variable), loadings_table_pc2.Loading,"FontSize",font_size);
%ylabel('Features');
%xlabel('Loadings on PC2');
title('Feature Loadings on 2nd Principal Component');
ax              = gca;
ax.YDir         = 'reverse';
ax.LineWidth    = 1.3;

% Find the variables that load the most on the first and second principal components
max_loading_variable_pc1 = loadings_table_pc1.Variable{1};
max_loading_variable_pc2 = loadings_table_pc2.Variable{1};
disp(['The variable that loads the most on the first principal component is: ', max_loading_variable_pc1]);
disp(['The variable that loads the most on the second principal component is: ', max_loading_variable_pc2]);

%% 2D and 3D t-SNE
Y = tsne(table2array(removevars(qc,new_vars)),"Standardize",true);
figure
gscatter(Y(:,1),Y(:,2),qc.echo)
title("2D t-SNE Embedding")

% 3D
Y2 = tsne(table2array(removevars(qc,new_vars)),...
    "Standardize",true,...
    "NumDimensions",3);
figure
scatter3(Y2(:,1),Y2(:,2),Y2(:,3),15,qc.echo,"filled")
title("3D t-SNE Embedding")