function selectedTable = get_selected_scan_table(batchCfg, required)
%GET_SELECTED_SCAN_TABLE Read local/selected_scans.csv.
if nargin < 2
    required = false;
end
filePath = fullfile(batchCfg.paths.projectRoot, 'local', 'selected_scans.csv');
if ~isfile(filePath)
    if required
        error(['Selected-scan mode requires:\n  %s\n', ...
               'Create a CSV with at least columns: deviceID,scanID'], filePath);
    end
    selectedTable = table();
    return;
end
selectedTable = readtable(filePath, 'TextType', 'string');
if ~ismember('deviceID', selectedTable.Properties.VariableNames) || ...
   ~ismember('scanID', selectedTable.Properties.VariableNames)
    error('selected_scans.csv must contain columns: deviceID, scanID');
end
selectedTable.deviceID = string(selectedTable.deviceID);
if ismember('rawName', selectedTable.Properties.VariableNames)
    selectedTable.rawName = string(selectedTable.rawName);
else
    selectedTable.rawName = strings(height(selectedTable), 1);
end
end
