function centerTable = append_or_replace_center_row(centerTable, batchName, deviceID, scanID, rawName, center)
%APPEND_OR_REPLACE_CENTER_ROW Update center table for one scan.
newRow = table(string(batchName), string(deviceID), double(scanID), string(rawName), ...
    center(1), center(2), string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    'VariableNames', {'batchName','deviceID','scanID','rawName','centerX_um','centerY_um','timeStamp'});

if isempty(centerTable) || height(centerTable) == 0
    centerTable = newRow;
    return;
end

centerTable.batchName = string(centerTable.batchName);
centerTable.deviceID = string(centerTable.deviceID);
centerTable.rawName = string(centerTable.rawName);

row = centerTable.deviceID == string(deviceID) & double(centerTable.scanID) == double(scanID);
if ~any(row)
    row = centerTable.rawName == string(rawName);
end

if any(row)
    idx = find(row, 1, 'first');
    centerTable(idx,:) = newRow;
else
    centerTable = [centerTable; newRow];
end
end
