function tables = match_subjects_across_groups(tables)
% Keep subjects that appear in all group
% Input: cell of tables, where each table has a "participant_id" column
    groups_n = length(tables);
    if groups_n > 1
        disp('Finding common subjects across all groups')    
        disp('Group sizes before subject matching:')
        disp(tables)
        % intersect tables
        for i_g = 1:groups_n
            for i_g2 = i_g+1:groups_n
                % where members of second table are found first table
                idx12       = ismember(tables{i_g}.participant_id,tables{i_g2}.participant_id);
                % where members of first table are found second table
                idx21       = ismember(tables{i_g2}.participant_id,tables{i_g}.participant_id);
                % only keep common rows in both tables
                tables{i_g} = tables{i_g}(idx12,:);
                tables{i_g2}= tables{i_g2}(idx21,:);
            end
        end
        disp('Group sizes after subject matching:')
        disp(tables)
    
        if isempty(tables{1})
            error('No common subjects found across groups')
        end
    end
end