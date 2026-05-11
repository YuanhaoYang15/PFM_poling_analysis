%% Analyze the active PFM poling batch
% Workflow:
%   main_pick_initial_centers_for_batch
%   main_analyze_batch

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
meta = read_batch_metadata(batchCfg);

if ~exist(batchCfg.paths.processedRoot, 'dir'); mkdir(batchCfg.paths.processedRoot); end
if ~exist(batchCfg.paths.figureRoot, 'dir'); mkdir(batchCfg.paths.figureRoot); end

centerTable = load_batch_initial_centers(batchCfg);

fprintf('\n========================================\n');
fprintf('Analyze batch: %s\n', batchCfg.batchName);
fprintf('Raw txt root: %s\n', batchCfg.paths.rawTxtRoot);
fprintf('Devices: %d\n', height(meta.devices));
fprintf('Scans:   %d\n', height(meta.scans));
fprintf('========================================\n\n');

allRows = {};
allResults = struct([]);

resultCounter = 0;

for dd = 1:height(meta.devices)
    deviceRow = meta.devices(dd,:);
    deviceID = string(deviceRow.deviceID);
    designID = string(deviceRow.designID);
    designRow = get_design_row(meta, designID);

    scanRows = meta.scans(meta.scans.deviceID == deviceID, :);
    if isempty(scanRows)
        warning('No scans found for device %s. Skipped.', deviceID);
        continue;
    end

    fprintf('\n----------------------------------------\n');
    fprintf('Device %s | design %s | %d scans\n', deviceID, designID, height(scanRows));
    fprintf('----------------------------------------\n');

    deviceResults = [];

    for ss = 1:height(scanRows)
        scanRow = scanRows(ss,:);
        [cfgScan, scanCfg] = build_scan_cfg_from_batch(batchCfg, deviceRow, scanRow, designRow);

        if isempty(scanCfg.centerInitial)
            [c0, found] = lookup_initial_center_from_table(centerTable, ...
                string(scanRow.deviceID), double(scanRow.scanID), string(scanRow.rawName));
            if found
                scanCfg.centerInitial = c0;
            end
        end

        fprintf('\n--- Analyze %s | scan %d | %s ---\n', ...
            deviceID, double(scanRow.scanID), string(scanRow.rawName));

        result = analyze_one_pfm_scan(cfgScan, scanCfg);
        result.batchName = batchCfg.batchName;
        result.deviceID = char(deviceID);
        result.designID = char(designID);
        result.deviceMetadata = deviceRow;
        result.designMetadata = designRow;

        save_processed_results(cfgScan, result);

        fig = plot_summary_figure(cfgScan, result);
        figName = sprintf('Summary_%s_scan_%d.png', char(deviceID), result.scanID);
        exportgraphics(fig, fullfile(cfgScan.paths.figures, figName), 'Resolution', cfgScan.plot.resolution);
        savefig(fig, fullfile(cfgScan.paths.figures, strrep(figName, '.png', '.fig')));

        if ss == 1
            deviceResults = result;
        else
            result = orderfields(result, deviceResults(1));
            deviceResults(ss) = result;
        end

        resultCounter = resultCounter + 1;
        allResults(resultCounter).result = result; %#ok<SAGROW>

        lambdaDesignAtR0 = cfgScan.design.periodRef.LambdaRef * cfgScan.design.R0 / cfgScan.design.periodRef.Rref;
        periodError = result.WG_period_mean - lambdaDesignAtR0;

        allRows(end+1,:) = { ...
            string(batchCfg.batchName), deviceID, designID, double(scanRow.scanID), ...
            string(scanRow.rawName), result.centerInitial(1), result.centerInitial(2), ...
            result.centerOptimized(1), result.centerOptimized(2), ...
            result.centerShift(1), result.centerShift(2), hypot(result.centerShift(1), result.centerShift(2)), ...
            result.WG_period_mean, result.WG_period_std, periodError, ...
            result.WG_duty_mean, result.WG_duty_std, result.WG_Nperiod_mean}; %#ok<SAGROW>
    end

    summary = make_device_summary(cfgScan, deviceResults);
    save(fullfile(cfgScan.paths.processedData, sprintf('%s_device_summary.mat', char(deviceID))), ...
        'summary', 'deviceResults', 'deviceRow', 'designRow');

    if numel(deviceResults) >= 2
        figCompare = plot_compare_scans(cfgScan, deviceResults);
        figName = sprintf('Compare_%s_all_scans.png', char(deviceID));
        exportgraphics(figCompare, fullfile(cfgScan.paths.figures, figName), 'Resolution', cfgScan.plot.resolution);
        savefig(figCompare, fullfile(cfgScan.paths.figures, strrep(figName, '.png', '.fig')));
    end
end

batchSummary = cell2table(allRows, 'VariableNames', { ...
    'batchName','deviceID','designID','scanID','rawName', ...
    'centerInitialX_um','centerInitialY_um', ...
    'centerOptimizedX_um','centerOptimizedY_um', ...
    'centerShiftX_um','centerShiftY_um','centerShiftAbs_um', ...
    'WG_period_mean_um','WG_period_std_um','WG_period_error_um', ...
    'WG_duty_mean','WG_duty_std','WG_Nperiod_mean'});

summaryMat = fullfile(batchCfg.paths.processedRoot, sprintf('batch_summary_%s.mat', batchCfg.batchName));
summaryCsv = fullfile(batchCfg.paths.processedRoot, sprintf('batch_summary_%s.csv', batchCfg.batchName));
save(summaryMat, 'batchCfg', 'meta', 'batchSummary', 'allResults', '-v7.3');
writetable(batchSummary, summaryCsv);

figBatch = plot_batch_summary(batchCfg, batchSummary);
figName = sprintf('Batch_summary_%s.png', batchCfg.batchName);
exportgraphics(figBatch, fullfile(batchCfg.paths.figureRoot, figName), 'Resolution', batchCfg.plot.resolution);
savefig(figBatch, fullfile(batchCfg.paths.figureRoot, strrep(figName, '.png', '.fig')));

fprintf('\nBatch analysis finished.\n');
fprintf('Batch summary:\n');
fprintf('  %s\n', summaryCsv);
fprintf('Figures:\n');
fprintf('  %s\n', batchCfg.paths.figureRoot);
