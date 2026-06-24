function tab = exclude_from_table(tab,exclusions)
% Exclude participants from table
% Inputs: tab [table], exclusions [table, cell array, or string array]
% Outputs: filtered table

    if ~istable(tab)
        error("The first argument is not a table.")
    end
    if ~ismember("participant_id",tab.Properties.VariableNames)
        error("Input table missing 'participant_id' column")
    end
    if ~istable(exclusions)
        % attempt to convert to string array
        unique_names                = string(unique(exclusions));
        if isrow(unique_names)
            unique_names = unique_names';
        end
        % store into table
        exclusions                  = table();
        exclusions.participant_id   = unique_names;
    end
    if ~ismember('participant_id',exclusions.Properties.VariableNames)
        error("Exclusion table missing 'participant_id' column")
    end

    % erase "sub-" prefix if present
    tab.participant_id          = erase(tab.participant_id,"sub-");
    exclusions.participant_id   = erase(exclusions.participant_id,"sub-");

    % convert to categorical variable type
    if ismember('ses',exclusions.Properties.VariableNames) && ismember('ses',tab.Properties.VariableNames) && isa(tab.ses(1),'categorical')
        exclusions.ses  = categorical(exclusions.ses,["Baseline","Administration"],"Ordinal",true);
    end
    if ismember('task',exclusions.Properties.VariableNames) && ismember('task',tab.Properties.VariableNames) && isa(tab.task(1),'categorical')
        taskorder       = ["rest","meditation","music","movie"];
        exclusions.task = categorical(exclusions.task,taskorder,"Ordinal",true);
    end
    if ismember('group',exclusions.Properties.VariableNames) && ismember('group',tab.Properties.VariableNames) && isa(tab.group(1),'categorical')
        % rename groups
        exclusions.group = replace(exclusions.group,"sub-PC2"+digitsPattern(2),"Meditators");
        exclusions.group = replace(exclusions.group,"sub-PC0"+digitsPattern(2),"Non-Meditators");
        % convert to categorical variable type
        exclusions.group = categorical(exclusions.group,["Non-Meditators","Meditators"],'Ordinal',true);
    end

    sprintf("List of participants to exclude:")
    disp(exclusions)

    % find common participants trying to match all columns
    [~,idx_left,idx_right]  = innerjoin(tab,exclusions);
    idx_left                = unique(idx_left);
    idx_right               = unique(idx_right);

    if ~isempty(idx_left)
        tab(idx_left,:)  = [];
        sprintf("These participants were successfully excluded:")
        disp(exclusions(idx_right,:))
        sprintf("These participants were not found:")
        exclusions(idx_right,:) = [];
        disp(exclusions)
        if isempty(tab)
            error("No participants left after exclusions.")
        end
    else
        warning("None of the participants to exclude were present.")
    end

end