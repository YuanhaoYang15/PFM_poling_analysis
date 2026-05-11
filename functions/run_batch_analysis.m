function run_batch_analysis(batchCfg, selectedOnly)
%RUN_BATCH_ANALYSIS Analyze a batch.
%
% selectedOnly = false:
%   reuse existing processed scans, analyze missing/new scans, regenerate summaries.
% selectedOnly = true:
%   force reprocess selected scans, reuse existing non-selected scans, regenerate summaries.

if nargin < 2
    selectedOnly = false;
end

batchCfg = set_default_batch_options(batchCfg);
meta = read_batch_metadata(batchCfg);

if ~exist(batchCfg.paths.processedRoot, 'dir'); mkdir(batchCfg.paths.processedRoot); end
if ~exist(batchCfg.paths.figureRoot, 'dir'); mkdir(batchCfg.paths.figureRoot); end

centerTable = load_batch_initial_centers(batchCfg);
selectedTable = get_selected_scan_table(batchCfg, selectedOnly);

fprintf('\n========================================\n');
fprintf('Analyze batch: %s\n', batchCfg.batchName);
fprintf('Raw txt root: %s\n', batchCfg.paths.rawTxtRoot);
fprintf('Devices: %d\n', height(meta.devices));
fprintf('Scans:   %d\n', height(meta.scans));
if selectedOnly
    fprintf('Mode: selected scans only (%d selected rows)\n', height(selectedTable));
else
    fprintf('Mode: incremental batch analysis\n');
end
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

    deviceResults = struct([]);

    for ss = 1:height(scanRows)
        scanRow = scanRows(ss,:);
        rawName = string(scanRow.rawName);
        scanID = double(scanRow.scanID);

        [cfgScan, scanCfg] = build_scan_cfg_from_batch(batchCfg, deviceRow, scanRow, designRow);

        isSelected = scan_is_selected(selectedTable, deviceID, scanID, rawName);
        if isSelected
            idxSel = selectedTable.deviceID == deviceID & double(selectedTable.scanID) == scanID;
            if any(idxSel)
                cfgScan = apply_selected_scan_overrides(cfgScan, selectedTable(find(idxSel, 1, 'first'), :));
            end
        end

        if isempty(scanCfg.centerInitial)
            [c0, found] = lookup_initial_center_from_table(centerTable, deviceID, scanID, rawName);
            if found
                scanCfg.centerInitial = c0;
            end
        end

        processedPath = get_processed_result_path(cfgScan, scanID);
        shouldProcess = true;

        if selectedOnly
            shouldProcess = isSelected;
        elseif batchCfg.run.skipExisting && ~batchCfg.run.forceReprocess && isfile(processedPath)
            shouldProcess = false;
        end

        if ~shouldProcess
            [result, foundExisting] = load_processed_result_if_available(cfgScan, scanID);
            if foundExisting
                fprintf('\n--- Load existing %s | scan %d | %s ---\n', deviceID, scanID, rawName);
                if batchCfg.run.regenerateFiguresForExisting
                    save_scan_figures(cfgScan, result);
                end
            else
                if selectedOnly
                    fprintf('\n--- Skip non-selected missing result %s | scan %d | %s ---\n', deviceID, scanID, rawName);
                    continue;
                else
                    shouldProcess = true;
                end
            end
        end

        if shouldProcess
            fprintf('\n--- Analyze %s | scan %d | %s ---\n', deviceID, scanID, rawName);
            result = analyze_one_pfm_scan(cfgScan, scanCfg);
            result.batchName = batchCfg.batchName;
            result.deviceID = char(deviceID);
            result.designID = char(designID);
            result.deviceMetadata = deviceRow;
            result.designMetadata = designRow;
            save_processed_results(cfgScan, result);
            save_scan_figures(cfgScan, result);
        end

        deviceResults = append_struct_result(deviceResults, result);
        resultCounter = resultCounter + 1;
        allResults(resultCounter).result = result; %#ok<AGROW>

        lambdaDesignAtR0 = cfgScan.design.periodRef.LambdaRef * cfgScan.design.R0 / cfgScan.design.periodRef.Rref;
        periodError = result.WG_period_mean - lambdaDesignAtR0;

        allRows(end+1,:) = { ...
            string(batchCfg.batchName), deviceID, designID, scanID, rawName, ...
            result.centerInitial(1), result.centerInitial(2), ...
            result.centerOptimized(1), result.centerOptimized(2), ...
            result.centerShift(1), result.centerShift(2), hypot(result.centerShift(1), result.centerShift(2)), ...
            result.WG_period_mean, result.WG_period_std, periodError, ...
            result.WG_duty_mean, result.WG_duty_std, result.WG_Nperiod_mean}; %#ok<AGROW>
    end

    if ~isempty(deviceResults)
        summary = make_device_summary(cfgScan, deviceResults);
        save(fullfile(cfgScan.paths.processedData, sprintf('%s_device_summary.mat', char(deviceID))), ...
            'summary', 'deviceResults', 'deviceRow', 'designRow');

        if numel(deviceResults) >= 2
            figCompare = plot_compare_scans(cfgScan, deviceResults);
            figName = sprintf('Compare_%s_all_scans.png', char(deviceID));
            save_analysis_figure(figCompare, fullfile(cfgScan.paths.figures, figName), cfgScan);
        end
    end
end

if isempty(allRows)
    warning('No results available for batch summary.');
    return;
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
save_analysis_figure(figBatch, fullfile(batchCfg.paths.figureRoot, figName), batchCfg);

fprintf('\nBatch analysis finished.\n');
fprintf('Batch summary:\n  %s\n', summaryCsv);
fprintf('Figures:\n  %s\n', batchCfg.paths.figureRoot);

end

function save_scan_figures(cfgScan, result)
    fig = plot_summary_figure(cfgScan, result);
    figName = sprintf('Summary_%s_scan_%d.png', cfgScan.deviceName, result.scanID);
    save_analysis_figure(fig, fullfile(cfgScan.paths.figures, figName), cfgScan);
end

function resultsOut = append_struct_result(resultsIn, result)
    if isempty(resultsIn)
        resultsOut = result;
    else
        result = orderfields(result, resultsIn(1));
        resultsOut = resultsIn;
        resultsOut(end+1) = result;
    end
end
