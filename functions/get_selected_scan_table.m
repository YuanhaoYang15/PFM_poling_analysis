function selectedTable = get_selected_scan_table(batchCfg, required)
%GET_SELECTED_SCAN_TABLE Read selected-scans table.
%
% Preferred:
%   local/selected_scans_batch_<batchName>.csv
% Fallback:
%   local/selected_scans.csv

if nargin < 2
    required = false;
end

batchFile = get_selected_scan_file(batchCfg);
legacyFile = fullfile(batchCfg.paths.projectRoot, 'local', 'selected_scans.csv');

if isfile(batchFile)
    filePath = batchFile;
elseif isfile(legacyFile)
    filePath = legacyFile;
else
    if required
        error(['Selected-scan mode requires a selected-scan table.\n', ...
               'Run main_select_scans_for_rework first, or create:\n  %s\n', ...
               'Required columns: deviceID, scanID'], batchFile);
    end
    selectedTable = table();
    return;
end

selectedTable = readtable(filePath, 'TextType', 'string');

if ~ismember('deviceID', selectedTable.Properties.VariableNames) || ...
        ~ismember('scanID', selectedTable.Properties.VariableNames)
    error('Selected-scans CSV must contain columns: deviceID, scanID');
end

selectedTable.deviceID = string(selectedTable.deviceID);

if ismember('rawName', selectedTable.Properties.VariableNames)
    selectedTable.rawName = string(selectedTable.rawName);
else
    selectedTable.rawName = strings(height(selectedTable), 1);
end

if ~ismember('action', selectedTable.Properties.VariableNames)
    selectedTable.action = repmat("reanalyze", height(selectedTable), 1);
else
    selectedTable.action = string(selectedTable.action);
end

if ~ismember('notes', selectedTable.Properties.VariableNames)
    selectedTable.notes = strings(height(selectedTable), 1);
else
    selectedTable.notes = string(selectedTable.notes);
end

end
