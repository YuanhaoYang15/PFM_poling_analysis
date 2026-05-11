function [center, found] = lookup_initial_center_from_table(centerTable, deviceID, scanID, rawName)
%LOOKUP_INITIAL_CENTER_FROM_TABLE Find a picked center in centerTable.

center = [];
found = false;

if isempty(centerTable) || height(centerTable) == 0
    return;
end

deviceID = string(deviceID);
rawName = string(rawName);
scanID = double(scanID);

% Normalize variable types.
if ~isstring(centerTable.deviceID); centerTable.deviceID = string(centerTable.deviceID); end
if ~isstring(centerTable.rawName);  centerTable.rawName  = string(centerTable.rawName);  end

row = centerTable.deviceID == deviceID & double(centerTable.scanID) == scanID;

if ~any(row)
    row = centerTable.rawName == rawName;
end

if any(row)
    idx = find(row, 1, 'first');
    center = [double(centerTable.centerX_um(idx)), double(centerTable.centerY_um(idx))];
    found = all(isfinite(center));
end

end
