function tab = bids_filenames_to_table(filenames_pattern,rename)

if nargin < 2
    rename   = true;
end

columns      = ["sub","ses","task","run","hemi"];
taskorder    = ["rest","meditation","music","movie"];

tab          = table();

% read file paths into table
temp         = dir(filenames_pattern);
tab.path     = string(fullfile({temp.folder}',{temp.name}')); % full paths
tab.filename = string(fullfile({temp.name}')); % only file names

% attempt to find columns
for col = columns
    match    = extractBetween(tab.filename, col+"-", "_");
    if ~isempty(match)
        tab.(col) = col + "-" + match;
    else
        fprintf("Couldn't read '%s' from file names \n",col)
    end
end

% rename "sub" column to "participant_id"
tab         = renamevars(tab,"sub","participant_id");

if rename
    % rename sessions
    if any(strcmp(tab.Properties.VariableNames, "ses"))
        tab.ses     = strrep(tab.ses,"ses-01","Baseline");
        tab.ses     = strrep(tab.ses,"ses-02","Administration");
        % convert to categorical variable type
        tab.ses     = categorical(tab.ses,["Baseline","Administration"],'Ordinal',true);
    end

    % rename tasks
    if any(strcmp(tab.Properties.VariableNames, "task"))
        tab.task    = erase(tab.task,"task-");
        % convert to categorical variable type
        tab.task    = categorical(tab.task,taskorder,'Ordinal',true);
    end

    % rename runs
    if any(strcmp(tab.Properties.VariableNames, "run"))
        tab.run     = erase(tab.run,"run-");
    end
   
    % label meditators vs non-meditators
    tab.group   = tab.participant_id;
    tab.group   = replace(tab.group,"sub-PC2"+digitsPattern(2),"Meditators");
    tab.group   = replace(tab.group,"sub-PC0"+digitsPattern(2),"Non-Meditators");
    % convert to categorical variable type
    tab.group   = categorical(tab.group,["Non-Meditators","Meditators"],'Ordinal',true);

    % rename hemispheres
    if any(strcmp(tab.Properties.VariableNames, "hemi"))
        tab.hemi    = erase(tab.hemi,"hemi-");
    end
end
