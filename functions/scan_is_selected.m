function tf = scan_is_selected(selectedTable, deviceID, scanID, rawName)
%SCAN_IS_SELECTED True if scan is listed in selectedTable.

tf = false;

if isempty(selectedTable) || height(selectedTable) == 0
    return;
end

deviceID = string(deviceID);
rawName = string(rawName);
scanID = double(scanID);

selectedTable.deviceID = string(selectedTable.deviceID);

row = selectedTable.deviceID == deviceID & double(selectedTable.scanID) == scanID;

if ~any(row) && ismember('rawName', selectedTable.Properties.VariableNames)
    selectedTable.rawName = string(selectedTable.rawName);
    row = selectedTable.rawName == rawName;
end

tf = any(row);

end
