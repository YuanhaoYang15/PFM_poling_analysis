function test_inphase_runner_modes(caseNumbers, stateFile)
%TEST_INPHASE_RUNNER_MODES Exercise click-free, picked, grid and reuse paths.
% Optional chunks: test_inphase_runner_modes(1, 't02_runner_state.mat'),
% then test_inphase_runner_modes(2:6, 't02_runner_state.mat').
projectRoot = fileparts(fileparts(mfilename('fullpath')));
oldPath = path;
pathCleanup = onCleanup(@() path(oldPath));
oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder));
figureCleanup = onCleanup(@() close('all'));
addpath(fullfile(projectRoot, 'functions'), fullfile(projectRoot, 'config'));
configRoot = fullfile(projectRoot, 'local', 'test_configs');
if ~isfolder(configRoot); mkdir(configRoot); end
addpath(configRoot);
cd(projectRoot);
oldThreads = maxNumCompThreads(1);
threadCleanup = onCleanup(@() maxNumCompThreads(oldThreads));
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
failures = 0;
casePassed = false(1, 6);
caseRan = false(1, 6);
cfgAuto = [];
summaryAuto = [];
autoResults = [];
batchWallTime_s = NaN;
qcPath = '';
if nargin < 1 || isempty(caseNumbers); caseNumbers = 1:6; end
assert(isnumeric(caseNumbers) && isvector(caseNumbers) && all(isfinite(caseNumbers)) && ...
    all(caseNumbers == floor(caseNumbers)) && all(ismember(caseNumbers, 1:6)), ...
    'caseNumbers must contain integer case indices from 1 through 6.');
caseNumbers = unique(caseNumbers(:).');
if nargin < 2 || isempty(stateFile)
    stateFile = fullfile(configRoot, ['t02_runner_modes_', stamp, '.mat']);
end
stateFile = state_file_local(stateFile, configRoot);
if isfile(stateFile)
    savedState = load(stateFile);
    requiredState = {'stateProjectRoot','cfgAuto','summaryAuto','autoResults','casePassed', ...
        'caseRan','failures','batchWallTime_s','qcPath','stamp'};
    assert(all(isfield(savedState, requiredState)) && ...
        strcmpi(savedState.stateProjectRoot, projectRoot), 'Invalid runner test state file.');
    cfgAuto = savedState.cfgAuto;
    summaryAuto = savedState.summaryAuto;
    autoResults = savedState.autoResults;
    casePassed = savedState.casePassed;
    caseRan = savedState.caseRan;
    failures = savedState.failures;
    batchWallTime_s = savedState.batchWallTime_s;
    qcPath = savedState.qcPath;
    stamp = savedState.stamp;
    fprintf('RESUME runner modes: attempted=%s passed=%s failures=%d\n', ...
        mat2str(find(caseRan)), mat2str(find(casePassed)), failures);
end
fprintf('RUNNER TEST STATE %s\n', stateFile);

if ismember(1, caseNumbers) && ~caseRan(1)
try
    cfgAuto = make_batch_local(projectRoot, configRoot, stamp, 'auto', '20260902');
    paths = get_batch_center_paths(cfgAuto);
    assert(~isfile(paths.mat), 'Click-free batch must have no picked-center file.');
    timer = tic;
    run_runner_local(cfgAuto.batchName, false);
    batchWallTime_s = toc(timer);
    [summaryAuto, autoResults] = load_summary_local(cfgAuto);
    required = {'centerSource','centerMethod','centerCoherence','centerPeakRatio', ...
        'centerPeriodError_um','centerFlag','centerFlagReason'};
    assert(height(summaryAuto) == 12, 'Expected 12 summary rows.');
    names = summaryAuto.Properties.VariableNames;
    dutyColumn = find(strcmp(names, 'dutyDefinition'));
    assert(isequal(names(dutyColumn+(1:numel(required))), required), ...
        'New center columns must follow dutyDefinition in the specified order.');
    assert(all(string(summaryAuto.centerSource) == "auto"), 'Expected all auto centers.');
    assert(all(string(summaryAuto.centerMethod) == "coherence"), 'Expected all coherence centers.');
    assert(~any(summaryAuto.centerFlag), 'Expected no center flags for 20260902.');
    qcPath = fullfile(cfgAuto.paths.inphaseFigureRoot, ...
        sprintf('Batch_center_qc_%s_inphase.png', cfgAuto.batchName));
    assert(isfile(qcPath), 'The single-page center QC PNG is missing.');
    qcFigure = openfig(strrep(qcPath, '.png', '.fig'), 'invisible');
    assert(numel(findall(qcFigure, 'Type', 'axes')) == 12, 'The QC sheet must contain 12 tiles.');
    close(qcFigure);
    maxDutyDifference = 0;
    for k = 1:numel(autoResults)
        result = autoResults(k).result;
        direct = optimize_center_by_inphase_coherence(result.data, [], result.configUsed);
        analysis = extract_inphase_duty_vs_radius(result.data, direct.centerBest, ...
            result.radiusList, result.configUsed);
        duty = mean(analysis.dutyMean(result.WG_mask), 'omitnan');
        row = string(summaryAuto.rawName) == string(result.rawName);
        assert(nnz(row) == 1, 'Summary scan lookup must be unique.');
        difference = abs(summaryAuto.WG_duty_mean(row) - duty);
        assert(isfinite(difference) && difference <= 1e-9, ...
            'Runner/direct duty mismatch for %s: %.17g.', result.rawName, difference);
        maxDutyDifference = max(maxDutyDifference, difference);
    end
    casePassed(1) = true;
    fprintf('PASS G1 click-free: rows=12 source=auto method=coherence flags=0 maxDutyDifference=%.17g batchWallTime=%.6f s\n', ...
        maxDutyDifference, batchWallTime_s);
    fprintf('QC SHEET G1 %s\n', qcPath);
catch exception
    failures = failures + report_failure_local('G1', exception);
end
caseRan(1) = true;
save_state_local(stateFile, projectRoot, cfgAuto, summaryAuto, autoResults, ...
    casePassed, caseRan, failures, batchWallTime_s, qcPath, stamp);
end

if ismember(2, caseNumbers) && ~caseRan(2)
try
    cfgManual = make_batch_local(projectRoot, configRoot, stamp, 'picked', '20260902');
    sourceCfg = config_batch_20260902();
    centerTable = load_batch_initial_centers(sourceCfg);
    assert(height(centerTable) == 12, 'Expected 12 supplied picked centers.');
    save_centers_local(cfgManual, centerTable);
    run_runner_local(cfgManual.batchName, false);
    summary = load_summary_local(cfgManual);
    assert(height(summary) == 12 && all(string(summary.centerSource) == "manual"), ...
        'All 12 scans must use the supplied picked centers.');
    casePassed(2) = true;
    fprintf('PASS G2 picked-center preference: rows=12 source=manual for every scan\n');
catch exception
    failures = failures + report_failure_local('G2', exception);
end
caseRan(2) = true;
save_state_local(stateFile, projectRoot, cfgAuto, summaryAuto, autoResults, ...
    casePassed, caseRan, failures, batchWallTime_s, qcPath, stamp);
end

if ismember(3, caseNumbers) && ~caseRan(3)
try
    cfgGrid = make_batch_local(projectRoot, configRoot, stamp, 'grid', '20260902');
    meta = read_batch_metadata(cfgGrid);
    keep = meta.scans.deviceID == meta.devices.deviceID(1);
    cfgGrid = filter_metadata_local(cfgGrid, meta, keep);
    cfgGrid.centerInit.method = 'manual';
    cfgGrid.centerOpt.method = 'grid';
    cfgGrid.centerOpt.searchRange = 0.3;
    write_config_local(configRoot, cfgGrid);
    sourceCfg = config_batch_20260902();
    centerTable = load_batch_initial_centers(sourceCfg);
    save_centers_local(cfgGrid, centerTable);
    run_runner_local(cfgGrid.batchName, false);
    [summary, results] = load_summary_local(cfgGrid);
    assert(height(summary) == 2 && numel(results) == 2, 'Expected two grid scans.');
    assert(all(string(summary.centerMethod) == "grid"), 'Expected grid centerMethod.');
    maxCenterDifference = 0;
    for k = 1:numel(results)
        result = results(k).result;
        assert(strcmp(result.centerOpt.mode, 'inphase_period_edge_refine'), ...
            'Expected the unchanged legacy optimizer mode.');
        assert(result.configUsed.centerOpt.searchRange == 0.3, 'Expected the small legacy search range.');
        direct = optimize_center_by_inphase_period(result.data, result.centerInitial, result.configUsed);
        difference = norm(result.centerOptimized - direct.centerBest);
        assert(isequaln(result.centerOptimized, direct.centerBest), ...
            'Legacy runner/direct centers differ for %s: %.17g.', result.rawName, difference);
        maxCenterDifference = max(maxCenterDifference, difference);
    end
    casePassed(3) = true;
    fprintf('PASS G3 legacy grid: scans=2 mode=inphase_period_edge_refine maxCenterDifference=%.17g um\n', ...
        maxCenterDifference);
catch exception
    failures = failures + report_failure_local('G3', exception);
end
caseRan(3) = true;
save_state_local(stateFile, projectRoot, cfgAuto, summaryAuto, autoResults, ...
    casePassed, caseRan, failures, batchWallTime_s, qcPath, stamp);
end

if ismember(4, caseNumbers) && ~caseRan(4)
try
    assert(casePassed(1), 'G4 requires a successful G1 batch.');
    pickedResult = autoResults(1).result;
    sourceCfg = config_batch_20260902();
    sourceCenters = load_batch_initial_centers(sourceCfg);
    [pickedCenter, found] = lookup_initial_center_from_table(sourceCenters, ...
        pickedResult.deviceID, pickedResult.scanID, pickedResult.rawName);
    assert(found, 'A supplied manual center is required for the rework scan.');
    centerTable = append_or_replace_center_row(table(), cfgAuto.batchName, ...
        pickedResult.deviceID, pickedResult.scanID, pickedResult.rawName, pickedCenter);
    save_centers_local(cfgAuto, centerTable);
    selected = table(string(pickedResult.deviceID), pickedResult.scanID, ...
        string(pickedResult.rawName), 5.5, 'VariableNames', ...
        {'deviceID','scanID','rawName','centerSearchRange_um'});
    writetable(selected, get_selected_scan_file(cfgAuto));
    beforeFiles = result_files_local(cfgAuto, autoResults);
    logPath = fullfile(cfgAuto.paths.inphaseResultRoot, 'progress.log');
    oldLog = fileread(logPath);
    run_runner_local(cfgAuto.batchName, true);
    [summary, results] = load_summary_local(cfgAuto);
    selectedRow = string(summary.rawName) == string(pickedResult.rawName);
    assert(height(summary) == 12 && nnz(selectedRow) == 1, 'Rework must preserve all 12 summary rows.');
    assert(string(summary.centerSource(selectedRow)) == "manual", 'Selected scan must use its picked center.');
    assert(all(string(summary.centerSource(~selectedRow)) == "auto"), 'Other scans must retain their auto source.');
    afterFiles = result_files_local(cfgAuto, autoResults);
    assert(isequaln(beforeFiles(2:end,:), afterFiles(2:end,:)), ...
        'The 11 non-selected processed MAT files must remain untouched.');
    newLog = fileread(logPath);
    newLog = newLog(numel(oldLog)+1:end);
    assert(numel(regexp(newLog, 'SCAN [^\r\n]* REUSE ', 'match')) == 11, ...
        'Selected-only run must report exactly 11 reused scans.');
    selectedResult = results(arrayfun(@(s) strcmp(s.result.rawName, pickedResult.rawName), results)).result;
    assert(selectedResult.configUsed.centerOpt.coherence.localRange_um == 5.5, ...
        'Selected centerSearchRange_um must set the coherence local range.');
    casePassed(4) = true;
    fprintf('PASS G4 selected rework: rows=12 picked=1 reused=11 untouchedMATs=11 coherenceLocalRange=5.5 um\n');
catch exception
    failures = failures + report_failure_local('G4', exception);
end
caseRan(4) = true;
save_state_local(stateFile, projectRoot, cfgAuto, summaryAuto, autoResults, ...
    casePassed, caseRan, failures, batchWallTime_s, qcPath, stamp);
end

if ismember(5, caseNumbers) && ~caseRan(5)
try
    assert(casePassed(1), 'G5 requires a successful G1 batch.');
    resultPath = result_path_local(cfgAuto, autoResults(2).result);
    saved = load(resultPath, 'result');
    result = rmfield(saved.result, {'centerSource','centerMethod','centerQC'});
    save(resultPath, 'result', '-v7.3');
    oldFile = dir(resultPath);
    run_runner_local(cfgAuto.batchName, false);
    summary = load_summary_local(cfgAuto);
    row = string(summary.rawName) == string(result.rawName);
    assert(height(summary) == 12 && nnz(row) == 1, 'Expected all rows after old-format reuse.');
    assert(string(summary.centerSource(row)) == "" && string(summary.centerMethod(row)) == "", ...
        'Old-format source and method must be empty strings.');
    assert(isnan(summary.centerCoherence(row)) && isnan(summary.centerPeakRatio(row)) && ...
        isnan(summary.centerPeriodError_um(row)), 'Old-format numeric QC columns must be NaN.');
    assert(~summary.centerFlag(row) && string(summary.centerFlagReason(row)) == "", ...
        'Old-format flag and reason must be false and empty.');
    newFile = dir(resultPath);
    assert(oldFile.datenum == newFile.datenum && oldFile.bytes == newFile.bytes, ...
        'Old-format result must be reused without rewriting its MAT file.');
    casePassed(5) = true;
    fprintf('PASS G5 old-format reuse: rows=12 defaults="","",NaN,NaN,NaN,false,""; saved MAT unchanged\n');
catch exception
    failures = failures + report_failure_local('G5', exception);
end
caseRan(5) = true;
save_state_local(stateFile, projectRoot, cfgAuto, summaryAuto, autoResults, ...
    casePassed, caseRan, failures, batchWallTime_s, qcPath, stamp);
end

if ismember(6, caseNumbers) && ~caseRan(6)
try
    cfgFlag = make_batch_local(projectRoot, configRoot, stamp, 'flag', '20260820');
    meta = read_batch_metadata(cfgFlag);
    cfgFlag = filter_metadata_local(cfgFlag, meta, meta.scans.rawName == "SPN_Chip2A_BR_R2C6_2");
    write_config_local(configRoot, cfgFlag);
    run_runner_local(cfgFlag.batchName, false);
    [summary, ~, csvPath] = load_summary_local(cfgFlag);
    csvSummary = readtable(csvPath, 'TextType', 'string');
    assert(height(summary) == 1 && summary.centerFlag, 'The known missing-domain scan must be flagged.');
    assert(height(csvSummary) == 1 && flag_value_local(csvSummary.centerFlag), 'The CSV must preserve the flag.');
    reason = string(csvSummary.centerFlagReason);
    assert(contains(lower(reason), 'period error'), 'The CSV must include a period-error reason.');
    logText = fileread(fullfile(cfgFlag.paths.inphaseResultRoot, 'progress.log'));
    lines = regexp(logText, '[^\r\n]*CENTER_QC FLAG[^\r\n]*', 'match');
    assert(any(contains(string(lines), 'SPN_Chip2A_BR_R2C6_2') & ...
        contains(lower(string(lines)), 'period error')), 'The progress log must identify the flagged scan and reason.');
    casePassed(6) = true;
    fprintf('PASS G6 flag propagation: CSV centerFlag=true reason=%s\n', char(reason));
    fprintf('FLAG LOG %s\n', lines{end});
catch exception
    failures = failures + report_failure_local('G6', exception);
end
caseRan(6) = true;
save_state_local(stateFile, projectRoot, cfgAuto, summaryAuto, autoResults, ...
    casePassed, caseRan, failures, batchWallTime_s, qcPath, stamp);
end

fprintf('\nRunner modes finished: G1=%d G2=%d G3=%d G4=%d G5=%d G6=%d; hardFailures=%d; clickFreeBatchWallTime=%.6f s\n', ...
    casePassed, failures, batchWallTime_s);
if ~isempty(qcPath); fprintf('QC SHEET %s\n', qcPath); end
if failures > 0
    error('test_inphase_runner_modes:Failed', '%d runner-mode cases failed.', failures);
end
if all(caseRan) && all(casePassed)
    fprintf('PASS test_inphase_runner_modes\n');
else
    fprintf('PENDING test_inphase_runner_modes: cases=%s still need execution\n', mat2str(find(~caseRan)));
end
end

function stateFile = state_file_local(stateFile, configRoot)
assert((ischar(stateFile) && isrow(stateFile)) || (isstring(stateFile) && isscalar(stateFile)), ...
    'stateFile must be a single path under local/test_configs.');
stateFile = strrep(char(stateFile), '/', filesep);
[parent, name, extension] = fileparts(stateFile);
if isempty(parent)
    stateFile = fullfile(configRoot, [name, extension]);
else
    assert(strcmpi(parent, configRoot), 'stateFile must be directly under worktree local/test_configs.');
end
assert(~isempty(name) && strcmpi(extension, '.mat'), 'stateFile must name a MAT file.');
end

function save_state_local(stateFile, stateProjectRoot, cfgAuto, summaryAuto, autoResults, ...
        casePassed, caseRan, failures, batchWallTime_s, qcPath, stamp)
save(stateFile, 'stateProjectRoot', 'cfgAuto', 'summaryAuto', 'autoResults', ...
    'casePassed', 'caseRan', 'failures', 'batchWallTime_s', 'qcPath', 'stamp', '-v7.3');
end

function cfg = make_batch_local(projectRoot, configRoot, stamp, label, sourceBatch)
sourceFunction = str2func(['config_batch_', sourceBatch]);
source = sourceFunction();
sourceRoot = fullfile(projectRoot, 'local', 'batches', sourceBatch);
assert(strcmpi(source.paths.batchRoot, sourceRoot), 'Source batch must resolve to the worktree copy.');
cfg = source;
cfg.batchName = ['t02_', stamp, '_', label];
cfg.paths.projectRoot = projectRoot;
cfg = configure_local_batch_paths(cfg);
expectedRoot = fullfile(projectRoot, 'local', 'batches', cfg.batchName);
assert(strcmpi(cfg.paths.batchRoot, expectedRoot), 'Test batch root must stay under worktree local/batches/t02_*.');
assert(~isfolder(expectedRoot), 'Test output folder must be new; never delete old outputs.');
mkdir(expectedRoot);
cfg.paths.rawTxtRoot = fullfile(sourceRoot, 'raw');
cfg.paths.rawData = cfg.paths.rawTxtRoot;
cfg.metadata = source.metadata;
cfg.run.skipExisting = true;
cfg.run.forceReprocess = false;
cfg.run.regenerateFiguresForExisting = false;
cfg = set_default_batch_options(cfg);
write_config_local(configRoot, cfg);
fprintf('TEST BATCH %s\n', expectedRoot);
end

function write_config_local(configRoot, cfg)
functionName = ['config_batch_', cfg.batchName];
matName = [functionName, '.mat'];
save(fullfile(configRoot, matName), 'cfg');
filePath = fullfile(configRoot, [functionName, '.m']);
fid = fopen(filePath, 'w');
assert(fid >= 0, 'Cannot write test configuration %s.', filePath);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'function cfg = %s()\n', functionName);
fprintf(fid, 'S = load(fullfile(fileparts(mfilename(''fullpath'')), ''%s''), ''cfg'');\n', matName);
fprintf(fid, 'cfg = S.cfg;\nend\n');
clear cleanup;
rehash;
end

function cfg = filter_metadata_local(cfg, meta, keep)
assert(any(keep), 'Filtered test batch must have at least one scan.');
meta.scans = meta.scans(keep,:);
meta.devices = meta.devices(ismember(meta.devices.deviceID, meta.scans.deviceID),:);
meta.designs = meta.designs(ismember(meta.designs.designID, meta.devices.designID),:);
if ~isfolder(cfg.paths.metadataRoot); mkdir(cfg.paths.metadataRoot); end
cfg.metadata.designsFile = fullfile(cfg.paths.metadataRoot, 'designs.csv');
cfg.metadata.devicesFile = fullfile(cfg.paths.metadataRoot, 'devices.csv');
cfg.metadata.scansFile = fullfile(cfg.paths.metadataRoot, 'scans.csv');
writetable(meta.designs, cfg.metadata.designsFile);
writetable(meta.devices, cfg.metadata.devicesFile);
writetable(meta.scans, cfg.metadata.scansFile);
end

function save_centers_local(cfg, centerTable)
paths = get_batch_center_paths(cfg);
if ~isfolder(paths.root); mkdir(paths.root); end
centerTable.batchName(:) = string(cfg.batchName);
save(paths.mat, 'centerTable');
writetable(centerTable, paths.csv);
end

function run_runner_local(batchName, selectedOnly) %#ok<INUSD>
% The script consumes both inputs and clears this disposable workspace.
centerMode = 'inphase_optimized'; %#ok<NASGU>
regenerateFiguresForExisting = false; %#ok<NASGU>
run_inphase_batch_analysis;
end

function [summary, results, csvPath] = load_summary_local(cfg)
baseName = sprintf('batch_summary_%s_inphase', cfg.batchName);
saved = load(fullfile(cfg.paths.inphaseProcessedRoot, [baseName, '.mat']), 'batchSummary', 'allResults');
summary = saved.batchSummary;
results = saved.allResults;
csvPath = fullfile(cfg.paths.inphaseProcessedRoot, [baseName, '.csv']);
assert(isfile(csvPath), 'Batch CSV summary is missing.');
end

function fileInfo = result_files_local(cfg, results)
fileInfo = zeros(numel(results), 2);
for k = 1:numel(results)
    info = dir(result_path_local(cfg, results(k).result));
    assert(isscalar(info), 'Processed MAT file must exist.');
    fileInfo(k,:) = [info.datenum, info.bytes];
end
end

function filePath = result_path_local(cfg, result)
filePath = fullfile(cfg.paths.inphaseProcessedRoot, result.deviceID, ...
    sprintf('%s_scan_%d_processed.mat', result.deviceID, result.scanID));
end

function flag = flag_value_local(value)
if islogical(value) || isnumeric(value)
    flag = logical(value);
else
    flag = strcmpi(string(value), "true") | string(value) == "1";
end
end

function failed = report_failure_local(label, exception)
failed = 1;
fprintf('FAIL %s %s\n%s\n', label, exception.message, getReport(exception, 'extended', 'hyperlinks', 'off'));
end
