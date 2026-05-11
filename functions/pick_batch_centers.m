function pick_batch_centers(batchCfg, selectedOnly)
%PICK_BATCH_CENTERS Pick initial centers for a batch.
if nargin < 2
    selectedOnly = false;
end

batchCfg = set_default_batch_options(batchCfg);
meta = read_batch_metadata(batchCfg);
selectedTable = get_selected_scan_table(batchCfg, selectedOnly);

localDir = fullfile(batchCfg.paths.projectRoot, 'local');
if ~exist(localDir, 'dir'); mkdir(localDir); end
if ~exist(batchCfg.paths.processedRoot, 'dir'); mkdir(batchCfg.paths.processedRoot); end
if ~exist(batchCfg.paths.figureRoot, 'dir'); mkdir(batchCfg.paths.figureRoot); end

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
if selectedOnly
    fprintf('Mode: selected scans only (%d selected rows)\n', height(selectedTable));
else
    fprintf('Mode: missing centers only\n');
end
fprintf('========================================\n\n');

centerTable = existingTable;

for ii = 1:height(meta.scans)
    scanRow = meta.scans(ii,:);
    deviceID = string(scanRow.deviceID);
    scanID = double(scanRow.scanID);
    rawName = string(scanRow.rawName);

    isSelected = scan_is_selected(selectedTable, deviceID, scanID, rawName);
    if selectedOnly && ~isSelected
        continue;
    end

    deviceRow = meta.devices(meta.devices.deviceID == deviceID, :);
    if isempty(deviceRow)
        error('Device %s in scans table is not found in devices table.', deviceID);
    end
    designRow = get_design_row(meta, string(deviceRow.designID));
    [cfgScan, scanCfg] = build_scan_cfg_from_batch(batchCfg, deviceRow, scanRow, designRow);

    [existingCenter, foundExisting] = lookup_initial_center_from_table(centerTable, deviceID, scanID, rawName);

    if foundExisting && batchCfg.centerPicker.skipExisting && ~selectedOnly
        fprintf('Skip existing center: %s scan %d -> [%.4f, %.4f]\n', ...
            deviceID, scanID, existingCenter(1), existingCenter(2));
        continue;
    end

    data = load_pfm_data(cfgScan, scanCfg);

    initialGuess = [];
    if foundExisting
        initialGuess = existingCenter;
    elseif ~isempty(scanCfg.centerInitial)
        initialGuess = scanCfg.centerInitial;
    end

    fprintf('\n--- %s | scan %d | %s ---\n', deviceID, scanID, rawName);
    picked = pick_initial_center_for_scan(data, cfgScan, scanCfg, initialGuess);

    centerTable = append_or_replace_center_row(centerTable, batchCfg.batchName, deviceID, scanID, rawName, picked);

    save(centerFile, 'centerTable');
    writetable(centerTable, centerCsv);
    fprintf('Saved center: %s scan %d -> [%.6f, %.6f]\n', deviceID, scanID, picked(1), picked(2));
end

snippetFile = fullfile(localDir, sprintf('initial_centers_batch_%s_snippet.m', batchCfg.batchName));
write_center_snippet(centerTable, snippetFile);

fprintf('\nSaved initial centers:\n');
fprintf('  %s\n', centerFile);
fprintf('  %s\n', centerCsv);
fprintf('  %s\n', snippetFile);
end

function write_center_snippet(centerTable, snippetFile)
fid = fopen(snippetFile, 'w');
fprintf(fid, '%% Picked initial centers\n');
fprintf(fid, '%% Columns: deviceID, scanID, rawName, centerX_um, centerY_um\n\n');
for ii = 1:height(centerTable)
    fprintf(fid, '%% %s scan %d %-40s center = [%.6f, %.6f]\n', ...
        centerTable.deviceID(ii), centerTable.scanID(ii), centerTable.rawName(ii), ...
        centerTable.centerX_um(ii), centerTable.centerY_um(ii));
end
fclose(fid);
end
