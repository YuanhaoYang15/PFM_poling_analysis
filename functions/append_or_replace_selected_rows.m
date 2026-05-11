function selectedTable = append_or_replace_selected_rows(selectedTable, newRows)
%APPEND_OR_REPLACE_SELECTED_ROWS Merge selected-scan rows by deviceID+scanID.

if isempty(selectedTable) || height(selectedTable) == 0
    selectedTable = newRows;
    return;
end

selectedTable.deviceID = string(selectedTable.deviceID);
newRows.deviceID = string(newRows.deviceID);

for ii = 1:height(newRows)
    row = selectedTable.deviceID == newRows.deviceID(ii) & ...
          double(selectedTable.scanID) == double(newRows.scanID(ii));

    if any(row)
        idx = find(row, 1, 'first');
        selectedTable(idx, :) = align_table_row_to_reference(newRows(ii,:), selectedTable);
    else
        selectedTable = [selectedTable; align_table_row_to_reference(newRows(ii,:), selectedTable)]; %#ok<AGROW>
    end
end

end

function rowOut = align_table_row_to_reference(rowIn, refTable)
    rowOut = refTable(1,:);
    for kk = 1:numel(refTable.Properties.VariableNames)
        vn = refTable.Properties.VariableNames{kk};
        if ismember(vn, rowIn.Properties.VariableNames)
            rowOut.(vn) = rowIn.(vn);
        else
            if isstring(rowOut.(vn)); rowOut.(vn) = ""; end
            if isnumeric(rowOut.(vn)); rowOut.(vn) = NaN; end
        end
    end
end
