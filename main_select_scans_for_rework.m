%% Select scans for rework from batch summary
%
% This script avoids manually creating local/selected_scans*.csv.

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
batchCfg = set_default_batch_options(batchCfg);

summaryCsv = fullfile(batchCfg.paths.processedRoot, sprintf('batch_summary_%s.csv', batchCfg.batchName));

if ~isfile(summaryCsv)
    error('Batch summary not found:\n%s\nRun main_analyze_batch first.', summaryCsv);
end

S = readtable(summaryCsv, 'TextType', 'string');

fprintf('\n========================================\n');
fprintf('Select scans for rework | batch %s\n', batchCfg.batchName);
fprintf('Summary: %s\n', summaryCsv);
fprintf('========================================\n\n');

fprintf('%5s  %-16s  %-6s  %-24s  %10s  %10s  %10s\n', ...
    'Index', 'deviceID', 'scanID', 'rawName', 'periodErr', 'dutyMean', 'shiftAbs');
fprintf('%s\n', repmat('-', 1, 95));

for ii = 1:height(S)
    fprintf('%5d  %-16s  %-6d  %-24s  %+10.4f  %10.4f  %10.4f\n', ...
        ii, char(S.deviceID(ii)), double(S.scanID(ii)), char(S.rawName(ii)), ...
        double(S.WG_period_error_um(ii)), double(S.WG_duty_mean(ii)), double(S.centerShiftAbs_um(ii)));
end

fprintf('\nExamples: [2 5 10], 2, or [] to cancel.\n\n');
idx = input('Select scan indices for rework: ');
if isempty(idx)
    fprintf('No scans selected. Nothing changed.\n');
    return;
end
idx = unique(idx(:).');
idx = idx(idx >= 1 & idx <= height(S));
if isempty(idx)
    fprintf('No valid indices selected. Nothing changed.\n');
    return;
end

fprintf('\nAction options:\n');
fprintf('  1 = repick_center      re-pick center, then reanalyze\n');
fprintf('  2 = reanalyze          reanalyze only\n');
fprintf('  3 = larger_search      reanalyze with larger center search range\n');
fprintf('  4 = custom_fit_range   reanalyze with custom fit radius range\n');
actionInput = input('Choose action [1/2/3/4, default=2]: ', 's');
if isempty(actionInput); actionInput = '2'; end

centerSearchRange = NaN;
fitRMin = NaN;
fitRMax = NaN;

switch strtrim(actionInput)
    case '1'
        action = "repick_center";
    case '3'
        action = "larger_search";
        centerSearchRange = input('centerSearchRange_um [default=1.5]: ');
        if isempty(centerSearchRange); centerSearchRange = 1.5; end
    case '4'
        action = "custom_fit_range";
        fitRMin = input('fitRMin_um: ');
        fitRMax = input('fitRMax_um: ');
        if isempty(fitRMin) || isempty(fitRMax)
            error('custom_fit_range requires both fitRMin_um and fitRMax_um.');
        end
    otherwise
        action = "reanalyze";
end

notes = input('Notes for these scans [optional]: ', 's');

newRows = table();
newRows.selectedIndex = (1:numel(idx)).';
newRows.deviceID = S.deviceID(idx);
newRows.scanID = S.scanID(idx);
newRows.rawName = S.rawName(idx);
newRows.action = repmat(action, numel(idx), 1);
newRows.centerSearchRange_um = repmat(centerSearchRange, numel(idx), 1);
newRows.centerSearchStep_um = nan(numel(idx), 1);
newRows.fitRMin_um = repmat(fitRMin, numel(idx), 1);
newRows.fitRMax_um = repmat(fitRMax, numel(idx), 1);
newRows.notes = repmat(string(notes), numel(idx), 1);
newRows.timeStamp = repmat(string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), numel(idx), 1);

selectedFile = get_selected_scan_file(batchCfg);
if isfile(selectedFile)
    existing = readtable(selectedFile, 'TextType', 'string');
else
    existing = table();
end

if ~isempty(existing) && height(existing) > 0
    appendAns = input('Append/replace into existing selected list? [Y]/n: ', 's');
    if isempty(appendAns) || any(strcmpi(appendAns, {'y','yes'}))
        selectedTable = append_or_replace_selected_rows(existing, newRows);
    else
        selectedTable = newRows;
    end
else
    selectedTable = newRows;
end

write_selected_scan_table(batchCfg, selectedTable);

fprintf('\nSelected scans:\n');
disp(selectedTable(:, {'deviceID','scanID','rawName','action','centerSearchRange_um','fitRMin_um','fitRMax_um','notes'}));

fprintf('\nNext steps:\n');
if any(selectedTable.action == "repick_center")
    fprintf('  main_pick_centers_selected\n');
end
fprintf('  main_analyze_selected\n');
