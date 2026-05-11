%% Pick approximate initial centers for all scans in the active batch
% Workflow:
%   1. Set raw roots in local/local_paths.m.
%   2. Select batch in local/active_batch_config.m.
%   3. Edit metadata/designs_*.csv, devices_*.csv, scans_*.csv.
%   4. Run this script.
%   5. Click approximate center for each scan.
%
% Picked centers are saved to:
%   local/initial_centers_batch_<batchName>.mat
%   local/initial_centers_batch_<batchName>.csv

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();

meta = read_batch_metadata(batchCfg);

localDir = fullfile(batchCfg.paths.projectRoot, 'local');
if ~exist(localDir, 'dir'); mkdir(localDir); end

centerFile = fullfile(localDir, sprintf('initial_centers_batch_%s.mat', batchCfg.batchName));
centerCsv  = fullfile(localDir, sprintf('initial_centers_batch_%s.csv', batchCfg.batchName));

existingTable = table();
if isfile(centerFile)
    S = load(centerFile, 'centerTable');
    existingTable = S.centerTable;
end

fprintf('\n========================================\n');
fprintf('Pick initial centers for batch: %s\n', batchCfg.batchName);
fprintf('Raw txt root: %s\n', batchCfg.paths.rawTxtRoot);
fprintf('Number of scans: %d\n', height(meta.scans));
fprintf('========================================\n\n');

rows = {};

for ii = 1:height(meta.scans)
    scanRow = meta.scans(ii,:);
    deviceID = string(scanRow.deviceID);
    scanID = double(scanRow.scanID);
    rawName = string(scanRow.rawName);

    deviceRow = meta.devices(meta.devices.deviceID == deviceID, :);
    if isempty(deviceRow)
        error('Device %s in scans table is not found in devices table.', deviceID);
    end
    designRow = get_design_row(meta, string(deviceRow.designID));

    [cfgScan, scanCfg] = build_scan_cfg_from_batch(batchCfg, deviceRow, scanRow, designRow);

    [existingCenter, foundExisting] = lookup_initial_center_from_table(existingTable, deviceID, scanID, rawName);

    if foundExisting && batchCfg.centerPicker.skipExisting
        fprintf('Skip existing center: %s scan %d -> [%.4f, %.4f]\n', ...
            deviceID, scanID, existingCenter(1), existingCenter(2));
        picked = existingCenter;
    else
        data = load_pfm_data(cfgScan, scanCfg);

        initialGuess = [];
        if foundExisting
            initialGuess = existingCenter;
        elseif ~isempty(scanCfg.centerInitial)
            initialGuess = scanCfg.centerInitial;
        end

        fprintf('\n--- %s | scan %d | %s ---\n', deviceID, scanID, rawName);
        picked = pick_initial_center_for_scan(data, cfgScan, scanCfg, initialGuess);
    end

    rows(end+1,:) = { ...
        string(batchCfg.batchName), deviceID, scanID, rawName, ...
        picked(1), picked(2), string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))}; %#ok<SAGROW>
end

centerTableNew = cell2table(rows, 'VariableNames', ...
    {'batchName','deviceID','scanID','rawName','centerX_um','centerY_um','timeStamp'});

% Replace previous table for this batch with the newly generated one.
centerTable = centerTableNew;
save(centerFile, 'centerTable');
writetable(centerTable, centerCsv);

snippetFile = fullfile(localDir, sprintf('initial_centers_batch_%s_snippet.m', batchCfg.batchName));
fid = fopen(snippetFile, 'w');
fprintf(fid, '%% Initial centers picked for batch %s\n', batchCfg.batchName);
fprintf(fid, '%% Columns: deviceID, scanID, rawName, centerX_um, centerY_um\n\n');
for ii = 1:height(centerTable)
    fprintf(fid, '%% %s scan %d %-40s center = [%.6f, %.6f]\n', ...
        centerTable.deviceID(ii), centerTable.scanID(ii), centerTable.rawName(ii), ...
        centerTable.centerX_um(ii), centerTable.centerY_um(ii));
end
fclose(fid);

fprintf('\nSaved initial centers:\n');
fprintf('  %s\n', centerFile);
fprintf('  %s\n', centerCsv);
fprintf('  %s\n', snippetFile);
fprintf('\nYou can now run:\n');
fprintf('  main_analyze_batch\n\n');
