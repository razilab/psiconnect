function joined = add_behav(EC_tab,behav_name,dir_bids,dir_phenotype)
% find behavioural scores in TSV files

% look for behavioural scores in all TSV files within the bids/phenotype (sub)folder(s)
if ~isempty(behav_name)
    disp(['Attempting to find requested scores in all the tsv files' ...
        ' within the "phenotype" folder (and its subfolders)'])
    clear phen
    f_part              = fullfile(dir_bids,'participants.tsv');
    fprintf('Loading file: %s \n',f_part)
    phen.part           = struct2table(spm_load(char(f_part)));

    % load phenotype assessment spreadsheets (.tsv) from dir_phenotype
    % The first column of each spreadsheet must be named "participant_id".
    % Check that all columns indicating sessions/tasks etc have the same name
    % across spreadsheets
    f                   = spm_select('FPListRec',dir_phenotype,'.*\.tsv$');
    if isempty(f), f = {}; else; f = cellstr(f); end
    for i=1:numel(f)
        fprintf('Loading file: %s \n',f{i})
        f_name          = spm_file(f{i},'basename');
        % Replace dashes, white spaces, and parentheses with an underscore
        f_name          = regexprep(f_name, '[-\s]', '_');
        try
            table_new   = struct2table(spm_load(f{i}));
            % convert text to numbers unless the column contains only text
            for i_col = 1:width(table_new)
                temp_col = table_new.(i_col);
                if ~isnumeric(temp_col)
                    temp_col = str2double(temp_col);
                    if ~all(isnan(temp_col))
                        table_new.(i_col) = temp_col;
                    end
                end
            end
            % store new table in phenotype structure
            phen.(f_name)   = table_new;
        catch
            warning('Could not load TSV file: %s', f{i})
        end
    end

    % join participants.tsv with all the phenotype tables in dir_phenotype
    disp('Behavioural scores requested:')
    disp(behav_name)
    joined          = table();
    phen_tables     = fieldnames(phen);
    for i_sh = 1:length(phen_tables)
        tb          = phen_tables{i_sh};
        tb_fields   = phen.(tb).Properties.VariableNames;
        found       = intersect(tb_fields,behav_name);
        if ~isempty(found)
            fprintf('Score(s) found in "%s" spreadsheet:\n', tb)
            disp(found(:))
            if isempty(joined)
                joined      = phen.(tb);
            else
                joined      = outerjoin(joined,phen.(tb),'MergeKeys',true);
                % rename joined column
                column_names= joined.Properties.VariableNames;
                joined.Properties.VariableNames = erase(column_names,'_joined');
            end
        end
    end
    column_names    = joined.Properties.VariableNames;

    % Check that all scores have been found in at least one spreadsheet
    disp('Summary')
    disp('Score(s) found:')
    scores_found    = intersect(column_names,behav_name);
    disp(scores_found)
    % check if any scores are missing
    score_missing   = setdiff(behav_name,column_names);
    if ~isempty(score_missing)
        warning('Score(s) not found:')
        disp(score_missing)
        error('Score(s) not found')
    end
    %     % only keep columns corresponding to requested scores
    %     col_to_keep             = [{"participant_id"},behav_name(:)'];
    %     joined                  = joined(:,[col_to_keep{:}]);

    if ismember('ses',joined.Properties.VariableNames)
        % rename sessions
        joined.ses  = strrep(joined.ses,"ses-01","Baseline");
        joined.ses  = strrep(joined.ses,"ses-02","Administration");
        % convert to categorical variable type
        joined.ses  = categorical(joined.ses,["Baseline","Administration"],'Ordinal',true);
    end
    if ismember('task',joined.Properties.VariableNames)
        taskorder       = ["rest","meditation","music","movie"];
        % rename tasks
        joined.task     = erase(joined.task,"task-");
        % convert to categorical variable type
        joined.task     = categorical(joined.task,taskorder,'Ordinal',true);
    end
    if ismember('group',joined.Properties.VariableNames)
        % rename groups
        joined.group    = replace(joined.group,"sub-PC2"+digitsPattern(2),"Meditators");
        joined.group    = replace(joined.group,"sub-PC0"+digitsPattern(2),"Non-Meditators");
        % convert to categorical variable type
        joined.group    = categorical(joined.group,["Non-Meditators","Meditators"],'Ordinal',true);
    end

    % inner join and keep track of original row positions in first table
    GCM_cat                 = EC_tab;
    % erase "sub-" prefix in case it is omitted from some TSV files
    GCM_cat.participant_id  = erase(GCM_cat.participant_id,"sub-");
    joined.participant_id   = erase(joined.participant_id,"sub-");
    [joined, rows_in_temp]  = innerjoin(GCM_cat,joined);
    % sort rows in order to maintain the order in the first table
    [~, sortinds]           = sort(rows_in_temp);
    % apply this sort order to the new table
    joined                  = joined(sortinds,:);
%     if size(joined,1) < size(GCM_cat,1)
%         disp(joined)
%         error('Could not find score values for each subject/session')
%     elseif size(joined,1) > size(GCM_cat,1)
%         error(['Multiple values for the same score found across TSV files ' ...
%             'without enough info to match it to a single subject and session. ' ...
%             'Try adding a "ses" column to the TSV files if missing.'])
%     end

end
end