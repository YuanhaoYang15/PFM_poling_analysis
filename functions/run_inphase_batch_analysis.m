%% Analyze one batch from LS_PR_Inphase.
% Set batchName before running this script, or use main_analyze_inphase_batch.
% Results stay with the private batch under results/inphase.

if exist('batchName', 'var') && ~isempty(batchName)
    requestedBatchName = batchName;
else
    requestedBatchName = '20260511';
end
if exist('centerMode', 'var') && ~isempty(centerMode)
    requestedCenterMode = centerMode;
else
    requestedCenterMode = 'inphase_optimized';
end
if exist('selectedOnly', 'var') && ~isempty(selectedOnly)
    requestedSelectedOnly = logical(selectedOnly);
else
    requestedSelectedOnly = false;
end
if exist('regenerateFiguresForExisting', 'var') && ...
        ~isempty(regenerateFiguresForExisting)
    requestedRegenerateFigures = logical(regenerateFiguresForExisting);
else
    requestedRegenerateFigures = [];
end
clearvars -except requestedBatchName requestedCenterMode ...
    requestedSelectedOnly requestedRegenerateFigures;
clc; close all;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(fullfile(projectRoot, 'functions')));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'local'));

batchName = char(requestedBatchName);

cfgFcn = str2func(['config_batch_', batchName]);
batchCfg = cfgFcn();
batchCfg = set_default_batch_options(batchCfg);
if ~isempty(requestedRegenerateFigures)
    batchCfg.run.regenerateFiguresForExisting = requestedRegenerateFigures;
end
batchCfg.plot.showFigures = false;
batchCfg.plot.saveFigures = true;
batchCfg.plot.closeAfterSave = true;
batchCfg.plot.figureWindowStyle = 'normal';

outRoot = batchCfg.paths.inphaseResultRoot;
processedRoot = batchCfg.paths.inphaseProcessedRoot;
figureRoot = batchCfg.paths.inphaseFigureRoot;
logFile = fullfile(outRoot, 'progress.log');

if ~exist(outRoot, 'dir'); mkdir(outRoot); end
if ~exist(processedRoot, 'dir'); mkdir(processedRoot); end
if ~exist(figureRoot, 'dir'); mkdir(figureRoot); end

meta = read_batch_metadata(batchCfg);
totalScans = height(meta.scans);
if requestedSelectedOnly
    selectedTable = get_selected_scan_table(batchCfg, true);
else
    selectedTable = table();
end

log_line(logFile, sprintf('START batch=%s totalScans=%d selectedOnly=%d', ...
    batchName, totalScans, requestedSelectedOnly));
fprintf('Inphase processing | batch %s | %d scans\n', batchName, totalScans);
fprintf('Center mode: %s\n', requestedCenterMode);
if requestedSelectedOnly
    fprintf('Mode: selected scans only (%d selected rows)\n', height(selectedTable));
else
    fprintf('Mode: full inphase batch analysis\n');
end
fprintf('Output root: %s\n', outRoot);

allRows = {};
allResults = struct([]);
resultCounter = 0;
doneCounter = 0;

for dd = 1:height(meta.devices)
    deviceRow = meta.devices(dd,:);
    deviceID = string(deviceRow.deviceID);
    designID = string(deviceRow.designID);
    designRow = get_design_row(meta, designID);
    scanRows = meta.scans(meta.scans.deviceID == deviceID, :);

    if isempty(scanRows)
        continue;
    end

    deviceResults = struct([]);
    cfgScanLast = [];

    for ss = 1:height(scanRows)
        scanRow = scanRows(ss,:);
        rawName = string(scanRow.rawName);
        scanID = double(scanRow.scanID);

        [cfgScan, scanCfg] = build_scan_cfg_from_batch(batchCfg, deviceRow, scanRow, designRow);
        cfgScan.plot = batchCfg.plot;
        cfgScan.paths.processedData = fullfile(processedRoot, char(deviceID));
        cfgScan.paths.figures = fullfile(figureRoot, char(deviceID));
        if ~exist(cfgScan.paths.processedData, 'dir'); mkdir(cfgScan.paths.processedData); end
        if ~exist(cfgScan.paths.figures, 'dir'); mkdir(cfgScan.paths.figures); end
        cfgScan.progress.logFile = logFile;
        cfgScan.progress.scanLabel = sprintf('%s scan %d raw=%s', char(deviceID), scanID, char(rawName));
        cfgScanLast = cfgScan;

        isSelected = scan_is_selected(selectedTable, deviceID, scanID, rawName);
        if isSelected
            idxSel = selectedTable.deviceID == deviceID & double(selectedTable.scanID) == scanID;
            if any(idxSel)
                cfgScan = apply_selected_scan_overrides(cfgScan, selectedTable(find(idxSel, 1, 'first'), :));
            end
        end

        if requestedSelectedOnly && ~isSelected
            [result, foundExisting] = load_processed_result_if_available(cfgScan, scanID);
            if ~foundExisting
                report_progress(logFile, sprintf('SCAN %02d/%02d SKIP missing existing result %s', ...
                    doneCounter + 1, totalScans, cfgScan.progress.scanLabel));
                continue;
            end

            doneCounter = doneCounter + 1;
            report_progress(logFile, sprintf('SCAN %02d/%02d REUSE %s', ...
                doneCounter, totalScans, cfgScan.progress.scanLabel));
            deviceResults = append_struct_result_local(deviceResults, result);
            resultCounter = resultCounter + 1;
            allResults(resultCounter).result = result;

            allRows(end+1,:) = build_summary_row_local(batchName, deviceID, designID, ...
                scanID, rawName, result, cfgScan); %#ok<SAGROW>
            continue;
        end

        if ~requestedSelectedOnly && batchCfg.run.skipExisting && ...
                ~batchCfg.run.forceReprocess
            [result, foundExisting] = load_processed_result_if_available(cfgScan, scanID);
            if foundExisting
                doneCounter = doneCounter + 1;
                report_progress(logFile, sprintf('SCAN %02d/%02d REUSE %s', ...
                    doneCounter, totalScans, cfgScan.progress.scanLabel));

                if batchCfg.run.regenerateFiguresForExisting
                    fig = plot_inphase_summary_figure(cfgScan, result);
                    figName = sprintf('Summary_%s_scan_%d.png', char(deviceID), scanID);
                    save_analysis_figure(fig, fullfile(cfgScan.paths.figures, figName), cfgScan);
                end

                deviceResults = append_struct_result_local(deviceResults, result);
                resultCounter = resultCounter + 1;
                allResults(resultCounter).result = result;

                allRows(end+1,:) = build_summary_row_local(batchName, deviceID, designID, ...
                    scanID, rawName, result, cfgScan); %#ok<SAGROW>
                continue;
            end
        end

        report_progress(logFile, sprintf('SCAN %02d/%02d START %s', ...
            doneCounter + 1, totalScans, cfgScan.progress.scanLabel));
        rawFile = resolve_raw_txt_file(batchCfg.paths.rawTxtRoot, rawName);
        report_progress(logFile, sprintf('SCAN %02d/%02d READ rawFile=%s', ...
            doneCounter + 1, totalScans, rawFile));
        [D, info, raw] = read_pfm_txt_nanoscope_legacy(rawFile, cfgScan);
        if ~isfield(D, 'LS_PR_Inphase')
            error('LS_PR_Inphase not found in raw file: %s', rawFile);
        end

        x_um = linspace(0, info.scanX_um, info.nx);
        y_um = linspace(0, info.scanY_um, info.ny);
        [X, Y] = meshgrid(x_um, y_um);

        data = struct();
        data.X = X;
        data.Y = Y;
        data.phase = D.LS_PR_Inphase;
        data.inphase = D.LS_PR_Inphase;
        data.sourceFile = rawFile;
        data.sourceType = 'nanoscope_legacy_txt_inphase';
        data.info = info;
        data.raw = raw;
        data.channels = D;
        data.phaseField = 'LS_PR_Inphase';

        report_progress(logFile, sprintf('SCAN %02d/%02d CENTER %s mode=%s', ...
            doneCounter + 1, totalScans, cfgScan.progress.scanLabel, requestedCenterMode));
        [center0, center, centerOpt, oldResult, centerSource, centerMethod, centerQC] = resolve_inphase_center_local( ...
            requestedCenterMode, deviceID, scanID, cfgScan, scanCfg, data);

        report_progress(logFile, sprintf('SCAN %02d/%02d EXTRACT %s center=[%.4f, %.4f]', ...
            doneCounter + 1, totalScans, cfgScan.progress.scanLabel, center(1), center(2)));
        rList = cfgScan.radius.rMin:cfgScan.radius.dr:cfgScan.radius.rMax;
        analysis = extract_inphase_duty_vs_radius(data, center, rList, cfgScan);
        wgMask = rList >= cfgScan.design.R0 - cfgScan.design.w/2 & ...
                 rList <= cfgScan.design.R0 + cfgScan.design.w/2;

        result = oldResult;
        result.rawName = char(rawName);
        result.rawFileName = char(rawName);
        result.sourceFile = rawFile;
        result.deviceName = char(deviceID);
        result.scanID = scanID;
        result.positionLabel = getfield_or(scanCfg, 'positionLabel', '');
        result.notes = getfield_or(scanCfg, 'notes', '');
        result.data = data;
        result.centerInitial = center0;
        result.centerOptimized = center;
        result.centerShift = center - center0;
        result.centerOpt = centerOpt;
        result.centerSource = centerSource;
        result.centerMethod = centerMethod;
        result.centerQC = centerQC;
        result.radiusList = rList;
        result.before = analysis;
        result.after = analysis;
        result.WG_mask = wgMask;
        result.WG_period_mean = mean(analysis.periodMean(wgMask), 'omitnan');
        result.WG_period_std = std(analysis.periodMean(wgMask), 'omitnan');
        result.WG_period_err_mean = mean(analysis.periodStd(wgMask), 'omitnan');
        result.WG_duty_mean = mean(analysis.dutyMean(wgMask), 'omitnan');
        result.WG_duty_std = std(analysis.dutyMean(wgMask), 'omitnan');
        result.WG_duty_err_mean = mean(analysis.dutyStd(wgMask), 'omitnan');
        result.WG_Nperiod_mean = mean(analysis.nPeriods(wgMask), 'omitnan');
        result.configUsed = cfgScan;
        result.scanConfigUsed = scanCfg;
        result.batchName = batchName;
        result.deviceID = char(deviceID);
        result.designID = char(designID);
        result.deviceMetadata = deviceRow;
        result.designMetadata = designRow;
        result.signalField = 'LS_PR_Inphase';
        result.dutyDefinition = 'low_inphase';

        report_progress(logFile, sprintf('SCAN %02d/%02d SAVE %s', ...
            doneCounter + 1, totalScans, cfgScan.progress.scanLabel));
        save_processed_results(cfgScan, result);

        report_progress(logFile, sprintf('SCAN %02d/%02d FIGURE %s', ...
            doneCounter + 1, totalScans, cfgScan.progress.scanLabel));
        fig = plot_inphase_summary_figure(cfgScan, result);
        figName = sprintf('Summary_%s_scan_%d.png', char(deviceID), scanID);
        save_analysis_figure(fig, fullfile(cfgScan.paths.figures, figName), cfgScan);

        deviceResults = append_struct_result_local(deviceResults, result);
        resultCounter = resultCounter + 1;
        allResults(resultCounter).result = result;

        allRows(end+1,:) = build_summary_row_local(batchName, deviceID, designID, ...
            scanID, rawName, result, cfgScan); %#ok<SAGROW>

        doneCounter = doneCounter + 1;
        msg = sprintf('DONE %02d/%02d %s scan %d raw=%s lowInphaseDuty=%.6f period=%.6f', ...
            doneCounter, totalScans, char(deviceID), scanID, char(rawName), ...
            result.WG_duty_mean, result.WG_period_mean);
        fprintf('%s\n', msg);
        log_line(logFile, msg);
    end

    if ~isempty(deviceResults)
        summary = make_device_summary(cfgScanLast, deviceResults);
        save(fullfile(cfgScanLast.paths.processedData, sprintf('%s_device_summary.mat', char(deviceID))), ...
            'summary', 'deviceResults', 'deviceRow', 'designRow');

        if numel(deviceResults) >= 2
            figCompare = plot_compare_scans(cfgScanLast, deviceResults);
            figName = sprintf('Compare_%s_all_scans.png', char(deviceID));
            save_analysis_figure(figCompare, fullfile(cfgScanLast.paths.figures, figName), cfgScanLast);
        end
    end
end

if isempty(allRows)
    error('No inphase results were generated.');
end

batchSummary = cell2table(allRows, 'VariableNames', { ...
    'batchName','deviceID','designID','scanID','rawName', ...
    'centerInitialX_um','centerInitialY_um', ...
    'centerOptimizedX_um','centerOptimizedY_um', ...
    'centerShiftX_um','centerShiftY_um','centerShiftAbs_um', ...
    'WG_period_mean_um','WG_period_std_um','WG_period_error_um', ...
    'WG_duty_mean','WG_duty_std','WG_Nperiod_mean', ...
    'signalField','dutyDefinition', ...
    'centerSource','centerMethod','centerCoherence','centerPeakRatio', ...
    'centerPeriodError_um','centerFlag','centerFlagReason'});

batchCfgOut = batchCfg;
batchCfgOut.paths.processedRoot = processedRoot;
batchCfgOut.paths.figureRoot = figureRoot;
batchCfgOut.plot.dutyNotesYLim = [0.25, 0.75];
batchCfgOut.plot.dutyNotesReference = 0.5;
batchCfgOut.plot.dutyNotesXLabelMode = 'index';

summaryMat = fullfile(processedRoot, sprintf('batch_summary_%s_inphase.mat', batchName));
summaryCsv = fullfile(processedRoot, sprintf('batch_summary_%s_inphase.csv', batchName));
save(summaryMat, 'batchCfgOut', 'meta', 'batchSummary', 'allResults', '-v7.3');
writetable(batchSummary, summaryCsv);

figBatch = plot_batch_summary(batchCfgOut, batchSummary);
save_analysis_figure(figBatch, fullfile(figureRoot, sprintf('Batch_summary_%s_inphase.png', batchName)), batchCfgOut);

figDuty = plot_batch_duty_notes(batchCfgOut, batchSummary);
save_analysis_figure(figDuty, fullfile(figureRoot, sprintf('Batch_duty_notes_%s_inphase.png', batchName)), batchCfgOut);

qcResults = struct([]);
for kk = 1:numel(allResults)
    qcResults = append_struct_result_local(qcResults, allResults(kk).result);
end
figsQC = plot_center_qc_sheet(batchCfgOut, qcResults);
for pp = 1:numel(figsQC)
    if isscalar(figsQC)
        qcName = sprintf('Batch_center_qc_%s_inphase.png', batchName);
    else
        qcName = sprintf('Batch_center_qc_%s_inphase_p%d.png', batchName, pp);
    end
    save_analysis_figure(figsQC(pp), fullfile(figureRoot, qcName), batchCfgOut);
end
flagged = find(batchSummary.centerFlag);
fprintf('Center QC: %d flagged scans.\n', numel(flagged));
for kk = flagged(:).'
    report_progress(logFile, sprintf('CENTER_QC FLAG index=%d raw=%s reason=%s', ...
        kk, char(batchSummary.rawName(kk)), char(batchSummary.centerFlagReason(kk))));
end
fprintf(['Review Batch_center_qc_%s_inphase*.png; for flagged or incorrect centers run ', ...
    'main_select_scans_for_rework -> main_pick_centers_selected -> main_analyze_inphase_selected.\n'], batchName);

log_line(logFile, sprintf('ALL_DONE batch=%s scans=%d processedRoot=%s figures=%s', ...
    batchName, doneCounter, processedRoot, figureRoot));
fprintf('ALL_DONE batch=%s scans=%d\n', batchName, doneCounter);
fprintf('Processed root: %s\n', processedRoot);
fprintf('Figure root: %s\n', figureRoot);

function rawFile = resolve_raw_txt_file(rawRoot, rawName)
rawFile = fullfile(rawRoot, char(rawName));
[~,~,ext] = fileparts(rawFile);
if isempty(ext)
    rawFile = [rawFile, '.txt'];
end
if ~isfile(rawFile)
    error('Raw txt file not found: %s', rawFile);
end
end

function [center0, center, centerOpt, oldResult, centerSource, centerMethod, centerQC] = resolve_inphase_center_local( ...
        centerMode, deviceID, scanID, cfgScan, scanCfg, data)
centerSource = 'manual';
centerMethod = 'fixed';
centerQC = empty_center_qc_local();
switch lower(string(centerMode))
    case "phase_optimized"
        oldResultPath = fullfile(cfgScan.paths.processedRoot, char(deviceID), ...
            sprintf('%s_scan_%d_processed.mat', char(deviceID), scanID));
        if ~isfile(oldResultPath)
            error('Old phase processed result not found: %s', oldResultPath);
        end
        S = load(oldResultPath, 'result');
        oldResult = S.result;
        center0 = oldResult.centerInitial;
        center = oldResult.centerOptimized;
        centerOpt = struct( ...
            'mode', 'fixed_from_phase_optimized_center', ...
            'centerBest', center, ...
            'sourceResult', oldResultPath);

    case "inphase_optimized"
        switch lower(string(cfgScan.centerInit.method))
            case "manual"
                center0 = resolve_initial_center(cfgScan, scanCfg);
            case "auto"
                center0 = [];
                if cfgScan.centerInit.preferManual
                    [center0, ~] = find_initial_center(cfgScan, scanCfg);
                end
            otherwise
                error('Unknown cfg.centerInit.method: %s', cfgScan.centerInit.method);
        end
        if isempty(center0)
            centerSource = 'auto';
        end
        if ~cfgScan.centerOpt.enable
            if isempty(center0)
                [center0, search] = find_center_by_stripe_coherence(data, cfgScan, []);
            else
                search = struct('usedGlobal', false, 'peakRatio', NaN, 'hitWindowEdge', false);
            end
            center = center0;
            centerOpt = struct('mode', 'fixed_initial_center', 'centerBest', center);
            centerQC = fixed_center_qc_local(data, center, search, cfgScan);
        else
            centerMethod = char(lower(string(cfgScan.centerOpt.method)));
            switch centerMethod
                case 'coherence'
                    centerOpt = optimize_center_by_inphase_coherence(data, center0, cfgScan);
                    center0 = centerOpt.centerInitial;
                    centerQC = centerOpt.qc;
                case 'grid'
                    if isempty(center0)
                        center0 = find_center_by_stripe_coherence(data, cfgScan, []);
                    end
                    centerOpt = optimize_center_by_inphase_period(data, center0, cfgScan);
                    centerQC = empty_center_qc_local();
                    reason = string(centerOpt.boundaryWarning);
                    if strlength(reason) > 0
                        centerQC.flag = true;
                        centerQC.reasons = reason;
                    end
                    cfgFixed = cfgScan;
                    cfgFixed.centerOpt.radialPolish.enable = false;
                    [~, periodInfo] = polish_center_radial_period(data, centerOpt.centerBest, cfgFixed);
                    centerQC.finalPeriodError_um = periodInfo.finalPeriodError_um;
                otherwise
                    error('Unknown cfg.centerOpt.method: %s', cfgScan.centerOpt.method);
            end
            center = centerOpt.centerBest;
        end
        oldResult = struct();

    otherwise
        error('Unknown inphase center mode: %s', centerMode);
end
end

function log_line(logFile, msg)
fid = fopen(logFile, 'a');
if fid < 0
    warning('Cannot open progress log: %s', logFile);
    return;
end
fprintf(fid, '%s | %s\n', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), msg);
fclose(fid);
end

function report_progress(logFile, msg)
fprintf('%s\n', msg);
log_line(logFile, msg);
end

function resultsOut = append_struct_result_local(resultsIn, result)
if isempty(resultsIn)
    resultsOut = result;
    return;
end

fieldsOld = fieldnames(resultsIn);
fieldsNew = fieldnames(result);
allFields = [fieldsOld; setdiff(fieldsNew, fieldsOld, 'stable')];

resultsIn = ensure_struct_fields_local(resultsIn, allFields);
result = ensure_struct_fields_local(result, allFields);

resultsOut = orderfields(resultsIn, allFields);
result = orderfields(result, allFields);
resultsOut(end+1) = result;
end

function S = ensure_struct_fields_local(S, allFields)
for kk = 1:numel(allFields)
    f = allFields{kk};
    if ~isfield(S, f)
        [S.(f)] = deal([]);
    end
end
end

function row = build_summary_row_local(batchName, deviceID, designID, scanID, rawName, result, cfgScan)
periodError = result.WG_period_mean - design_period(cfgScan.design.R0, cfgScan);
qc = getfield_or(result, 'centerQC', []);
if isempty(qc)
    qc = empty_center_qc_local();
end
source = string(getfield_or(result, 'centerSource', ''));
method = string(getfield_or(result, 'centerMethod', ''));
row = {string(batchName), deviceID, designID, scanID, rawName, ...
    result.centerInitial(1), result.centerInitial(2), ...
    result.centerOptimized(1), result.centerOptimized(2), ...
    result.centerShift(1), result.centerShift(2), hypot(result.centerShift(1), result.centerShift(2)), ...
    result.WG_period_mean, result.WG_period_std, periodError, ...
    result.WG_duty_mean, result.WG_duty_std, result.WG_Nperiod_mean, ...
    string(result.signalField), string(result.dutyDefinition), source, method, ...
    qc.finalCoherence, qc.peakRatio, qc.finalPeriodError_um, logical(qc.flag), ...
    strjoin(string(qc.reasons(:).'), '; ')};
end

function qc = empty_center_qc_local()
qc = struct('flag', false, 'reasons', strings(0, 1), 'notes', strings(0, 1), ...
    'finalCoherence', NaN, 'peakRatio', NaN, 'finalPeriodError_um', NaN);
end

function qc = fixed_center_qc_local(data, center, search, cfg)
cfgFixed = cfg;
cfgFixed.centerOpt.radialPolish.enable = false;
[~, periodInfo] = polish_center_radial_period(data, center, cfgFixed);
rRange = cfg.centerOpt.coherence.radiusRange;
if isempty(rRange)
    rRange = [cfg.radius.rMin, cfg.radius.rMax];
end
N = 2*pi*cfg.design.periodRef.Rref / cfg.design.periodRef.LambdaRef;
J = center_stripe_coherence(center, data.X, data.Y, data.inphase, N, ...
    sort(rRange), cfg.centerOpt.coherence.taper_um, cfg.centerOpt.coherence.minPixels);
qc = empty_center_qc_local();
qc.finalCoherence = J;
qc.peakRatio = search.peakRatio;
qc.finalPeriodError_um = periodInfo.finalPeriodError_um;
if search.usedGlobal && search.peakRatio < cfg.centerOpt.coherence.minPeakRatio
    qc.reasons(end+1, 1) = sprintf('Global peak ratio %.4g is below %.4g.', ...
        search.peakRatio, cfg.centerOpt.coherence.minPeakRatio);
end
if J < cfg.centerOpt.coherence.minCoherence
    qc.reasons(end+1, 1) = sprintf('Final stripe coherence %.4g is below %.4g.', ...
        J, cfg.centerOpt.coherence.minCoherence);
end
if search.hitWindowEdge
    qc.reasons(end+1, 1) = "Local coherence search still reaches its window edge.";
end
if periodInfo.noValidCandidate || ~isfinite(periodInfo.finalPeriodError_um)
    qc.reasons(end+1, 1) = "Final period evaluation is not valid.";
elseif abs(periodInfo.finalPeriodError_um) > cfg.centerOpt.coherence.maxFinalPeriodError_um
    qc.reasons(end+1, 1) = sprintf('Final signed median period error %+.5g um exceeds %.5g um.', ...
        periodInfo.finalPeriodError_um, cfg.centerOpt.coherence.maxFinalPeriodError_um);
end
qc.flag = ~isempty(qc.reasons);
end
