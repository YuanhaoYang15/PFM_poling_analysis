function run_center_regression(maxScansPerInvocation)
%RUN_CENTER_REGRESSION Compare manual-start and click-free centers on 52 scans.
runTime = tic;
if nargin < 1; maxScansPerInvocation = Inf; end
if ~isnumeric(maxScansPerInvocation) || ~isscalar(maxScansPerInvocation) || ...
        ~isreal(maxScansPerInvocation) || isnan(maxScansPerInvocation) || ...
        maxScansPerInvocation <= 0 || ...
        (isfinite(maxScansPerInvocation) && maxScansPerInvocation ~= floor(maxScansPerInvocation))
    error('run_center_regression:InvalidChunkSize', 'Chunk size must be a positive integer or Inf.');
end
projectRoot = fileparts(fileparts(mfilename('fullpath')));
oldPath = path;
pathCleanup = onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(fullfile(projectRoot, 'functions'));
addpath(fullfile(projectRoot, 'config'));
outRoot = fullfile(projectRoot, 'local', 'regression_out');
if ~exist(outRoot, 'dir'); mkdir(outRoot); end
oldThreads = maxNumCompThreads(1);
threadCleanup = onCleanup(@() maxNumCompThreads(oldThreads)); %#ok<NASGU>
fprintf('Center regression: single computational thread; output=%s\n', outRoot);
batches = {'20260902','20260820','20260521_1','20260511_2','20260511_1','20260529'};
sourceText = source_text_local(projectRoot, batches);
checkpointFile = fullfile(outRoot, 'center_regression_checkpoint.mat');
failures = 0;
rows = repmat(empty_row_local(), 0, 1);
previousTime_s = 0;
if isfinite(maxScansPerInvocation) && isfile(checkpointFile)
    checkpoint = load(checkpointFile);
    required = {'rows','failures','sourceText','accumulatedTime_s','finished'};
    if ~all(isfield(checkpoint, required))
        error('run_center_regression:InvalidCheckpoint', 'Checkpoint is incomplete: %s', checkpointFile);
    end
    if ~checkpoint.finished
        if ~isequal(sourceText, checkpoint.sourceText)
            error('run_center_regression:CheckpointSourceChanged', ...
                'Numerical source changed. Cannot resume checkpoint %s; explicitly remove it to start a fresh run.', checkpointFile);
        end
        if ~isequal(fieldnames(checkpoint.rows), fieldnames(empty_row_local()))
            error('run_center_regression:CheckpointSchemaChanged', ...
                'Row schema changed. Cannot resume checkpoint %s; explicitly remove it to start a fresh run.', checkpointFile);
        end
        rows = checkpoint.rows(:);
        failures = checkpoint.failures;
        previousTime_s = checkpoint.accumulatedTime_s;
        fprintf('RESUME rows=%d accumulatedHardFailures=%d previousWallTime=%.6f s\n', ...
            numel(rows), failures, previousTime_s);
    else
        fprintf('START fresh regression after completed checkpoint; previous full-center snapshot retained.\n');
    end
elseif isinf(maxScansPerInvocation)
    fprintf('START fresh whole regression (no checkpoint resume).\n');
end
scansThisInvocation = 0;
expectedScans = 0;
for ib = 1:numel(batches)
    batch = batches{ib};
    fprintf('\nBATCH %s\n', batch);
    try
        cfgFcn = str2func(['config_batch_', batch]);
        batchCfg = set_default_batch_options(cfgFcn());
        % Pin inputs to these copies even if local_paths points elsewhere.
        batchRoot = fullfile(projectRoot, 'local', 'batches', batch);
        batchCfg.paths.projectRoot = projectRoot;
        batchCfg.paths.batchRoot = batchRoot;
        batchCfg.paths.rawTxtRoot = fullfile(batchRoot, 'raw');
        batchCfg.paths.centerRoot = fullfile(batchRoot, 'centers');
        batchCfg.metadata.designsFile = fullfile(batchRoot, 'metadata', 'designs.csv');
        batchCfg.metadata.devicesFile = fullfile(batchRoot, 'metadata', 'devices.csv');
        batchCfg.metadata.scansFile = fullfile(batchRoot, 'metadata', 'scans.csv');
        % build_scan_cfg_from_batch creates its output directories.
        batchCfg.paths.processedRoot = fullfile(outRoot, 'scratch', batch, 'processed');
        batchCfg.paths.figureRoot = fullfile(outRoot, 'scratch', batch, 'figures');
        meta = read_batch_metadata(batchCfg);
        centerTable = load_batch_initial_centers(batchCfg);
        reference = readtable(fullfile(projectRoot, 'local', 'reference', batch, ...
            ['batch_summary_', batch, '_inphase.csv']), 'TextType', 'string');
        expectedScans = expectedScans + height(meta.scans);
    catch exception
        failures = failures + 1;
        fprintf('FAIL C2 batch=%s input setup: %s\n%s\n', batch, exception.message, ...
            getReport(exception, 'extended', 'hyperlinks', 'off'));
        summarize_batch_local(batch_rows_local(rows, batch), batch);
        continue;
    end
    for iscan = 1:height(meta.scans)
        scanRow = meta.scans(iscan, :);
        if has_row_local(rows, batch, scanRow.rawName)
            fprintf('REUSE checkpoint batch=%s raw=%s\n', batch, char(scanRow.rawName));
            continue;
        end
        if scansThisInvocation >= maxScansPerInvocation; continue; end
        scanTime = tic;
        row = empty_row_local();
        row.batch = string(batch);
        row.rawName = string(scanRow.rawName);
        label = sprintf('batch=%s scan=%d/%d raw=%s', batch, iscan, height(meta.scans), char(row.rawName));
        try
            deviceMask = meta.devices.deviceID == string(scanRow.deviceID);
            if ~any(deviceMask); error('Device metadata missing for %s.', char(scanRow.deviceID)); end
            deviceRow = meta.devices(find(deviceMask, 1, 'first'), :);
            designRow = get_design_row(meta, deviceRow.designID);
            [cfg, scanCfg] = build_scan_cfg_from_batch(batchCfg, deviceRow, scanRow, designRow);
            cfg.progress.scanLabel = label;
            cfg.progress.logFile = fullfile(outRoot, 'center_regression_progress.log');
            [manual, found] = lookup_initial_center_from_table(centerTable, ...
                deviceRow.deviceID, scanRow.scanID, scanRow.rawName);
            if ~isempty(scanCfg.centerInitial)
                manual = scanCfg.centerInitial(:).';
                found = all(isfinite(manual));
            end
            if ~found; error('Finite manual center missing for %s.', char(scanRow.rawName)); end
            idxRef = find(string(reference.rawName) == row.rawName, 1, 'first');
            if isempty(idxRef); error('Reference row missing for %s.', char(scanRow.rawName)); end
            ref = reference(idxRef, :);
            refCenter = [ref.centerOptimizedX_um, ref.centerOptimizedY_um];
            row.R0_um = cfg.design.R0;
            row.LambdaRef_um = cfg.design.periodRef.LambdaRef;
            row.manualX_um = manual(1); row.manualY_um = manual(2);
            row.referenceX_um = refCenter(1); row.referenceY_um = refCenter(2);
            row.WGPeriodErrorReference_um = ref.WG_period_error_um;
            row.WGDutyReference = ref.WG_duty_mean;
            row.WGNPeriodsReference = ref.WG_Nperiod_mean;
            rawFile = fullfile(batchCfg.paths.rawTxtRoot, char(scanRow.rawName));
            [~, ~, extension] = fileparts(rawFile);
            if isempty(extension); rawFile = [rawFile, '.txt']; end
            [D, rawInfo] = read_pfm_txt_nanoscope_legacy(rawFile, cfg);
            if ~isfield(D, 'LS_PR_Inphase'); error('LS_PR_Inphase is absent in %s.', rawFile); end
            [X, Y] = meshgrid(linspace(0, rawInfo.scanX_um, rawInfo.nx), ...
                linspace(0, rawInfo.scanY_um, rawInfo.ny));
            data = struct('X', X, 'Y', Y, 'phase', D.LS_PR_Inphase, 'inphase', D.LS_PR_Inphase);
            row.referenceArcCrossedSeam = seam_crossed_local(data, refCenter, cfg.design.R0, cfg);
            optA = optimize_center_by_inphase_coherence(data, manual, cfg);
            optB = optimize_center_by_inphase_coherence(data, [], cfg);
            row.centerAX_um = optA.centerBest(1); row.centerAY_um = optA.centerBest(2);
            row.centerBX_um = optB.centerBest(1); row.centerBY_um = optB.centerBest(2);
            row.distanceAB_um = norm(optA.centerBest-optB.centerBest);
            row.coherenceA = optA.coherence.J; row.coherenceB = optB.coherence.J;
            row.finalCoherenceA = optA.finalJ; row.finalCoherenceB = optB.finalJ;
            row.peakRatioA = optA.coherence.peakRatio; row.peakRatioB = optB.coherence.peakRatio;
            row.polishTA_um = optA.polish.tBest; row.polishTB_um = optB.polish.tBest;
            row.polishAppliedA = logical(optA.polish.applied);
            row.polishAppliedB = logical(optB.polish.applied);
            row.polishReasonA = reasons_text_local(optA.polish.reason);
            row.polishReasonB = reasons_text_local(optB.polish.reason);
            row.agreeFractionA = optA.polish.agreeFraction;
            row.finalPeriodErrorA_um = optA.polish.finalPeriodError_um;
            row.qcA = optA.qc.flag; row.qcB = optB.qc.flag;
            row.reasonsA = reasons_text_local(optA.qc.reasons);
            row.reasonsB = reasons_text_local(optB.qc.reasons);
            row.qcNotesA = reasons_text_local(optA.qc.notes);
            row.qcNotesB = reasons_text_local(optB.qc.notes);
            row.timeA_s = optA.time_s; row.timeB_s = optB.time_s;
            radii = cfg.radius.rMin:cfg.radius.dr:cfg.radius.rMax;
            analysisA = extract_inphase_duty_vs_radius(data, optA.centerBest, radii, cfg);
            wg = radii >= cfg.design.R0-cfg.design.w/2 & radii <= cfg.design.R0+cfg.design.w/2;
            row.WGPeriodErrorA_um = mean(analysisA.periodMean(wg), 'omitnan') - design_period(cfg.design.R0, cfg);
            row.WGDutyA = mean(analysisA.dutyMean(wg), 'omitnan');
            row.WGNPeriodsA = mean(analysisA.nPeriods(wg), 'omitnan');
            analysisB = extract_inphase_duty_vs_radius(data, optB.centerBest, radii(wg), cfg);
            row.WGDutyB = mean(analysisB.dutyMean, 'omitnan');
            row.dDutyA = row.WGDutyA-row.WGDutyReference;
            row.complete = true;
            row.reading = reading_local(optA, optB, row.distanceAB_um, ...
                row.dDutyA, row.referenceArcCrossedSeam);
            fprintf('CENTERS %s manual=[%.8f %.8f] reference=[%.8f %.8f] A=[%.8f %.8f] B=[%.8f %.8f]\n', ...
                label, manual, refCenter, optA.centerBest, optB.centerBest);
            fprintf('VALUES |A-B|=%.8f stageJ=[%.6f %.6f] finalJ=[%.6f %.6f] peakRatioB=%.6f polish=[%+.4f %+.4f] periodErrA=%+.8f duty=[ref %.8f A %.8f B %.8f] dDutyA=%+.8f N=[ref %.5f A %.5f] qc=[%d %d] seam=%d optimizerTime=[%.3f %.3f] s\n', ...
                row.distanceAB_um, row.coherenceA, row.coherenceB, row.finalCoherenceA, ...
                row.finalCoherenceB, row.peakRatioB, ...
                row.polishTA_um, row.polishTB_um, row.WGPeriodErrorA_um, row.WGDutyReference, ...
                row.WGDutyA, row.WGDutyB, row.dDutyA, row.WGNPeriodsReference, row.WGNPeriodsA, ...
                row.qcA, row.qcB, row.referenceArcCrossedSeam, row.timeA_s, row.timeB_s);
            fprintf('POLISH applied=[%d %d] agreeFractionA=%.6f finalPeriodErrorMedianA=%+.8f um reasons=[A:%s B:%s] QCnotes=[A:%s B:%s]\n', ...
                row.polishAppliedA, row.polishAppliedB, row.agreeFractionA, ...
                row.finalPeriodErrorA_um, char(row.polishReasonA), char(row.polishReasonB), ...
                char(row.qcNotesA), char(row.qcNotesB));
            failures = failures + check_local(true, ['C2 completed ', label]);
            if row.qcA || row.qcB
                fprintf('REVIEW C3 FLAGGED %s A:%s B:%s; inference: %s\n', ...
                    label, char(row.reasonsA), char(row.reasonsB), char(row.reading));
            elseif abs(row.dDutyA) > 0.03
                fprintf('REVIEW C3 UNFLAGGED DUTY %s dDutyA=%+.8f expected report when |difference|>0.03; inference: %s\n', ...
                    label, row.dDutyA, char(row.reading));
            end
            if row.distanceAB_um > 0.02
                fprintf('REPORT EXTRA DISAGREEMENT %s |A-B|=%.8f um; inference: %s\n', ...
                    label, row.distanceAB_um, char(row.reading));
            end
        catch exception
            failures = failures + 1;
            row.complete = false;
            row.error = string(exception.message);
            fprintf('FAIL C2 %s: %s\n%s\n', label, exception.message, ...
                getReport(exception, 'extended', 'hyperlinks', 'off'));
        end
        rows(end+1, 1) = row; %#ok<AGROW>
        writetable(struct2table(rows), fullfile(outRoot, 'center_regression.csv'));
        % Include the per-scan checkpoint write in its complete pipeline time.
        rows(end).elapsed_s = toc(scanTime);
        fprintf('TIMING %s completePipeline=%.6f s\n', label, rows(end).elapsed_s);
        scansThisInvocation = scansThisInvocation + 1;
        save_checkpoint_local(checkpointFile, rows, failures, sourceText, ...
            previousTime_s + toc(runTime), false);
    end
    summarize_batch_local(batch_rows_local(rows, batch), batch);
end

result = struct2table(rows);
csvFile = fullfile(outRoot, 'center_regression.csv');
writetable(result, csvFile);
if height(result) < 52 && isfinite(maxScansPerInvocation)
    invocationTime_s = toc(runTime);
    accumulatedTime_s = previousTime_s + invocationTime_s;
    save_checkpoint_local(checkpointFile, rows, failures, sourceText, accumulatedTime_s, false);
    fprintf('NOT CHECKED final C1/C2/D1: processed=%d/52 pending=%d newlyProcessed=%d accumulatedHardFailures=%d invocationTime=%.6f s accumulatedTime=%.6f s; checkpoint=%s\n', ...
        height(result), 52-height(result), scansThisInvocation, failures, invocationTime_s, accumulatedTime_s, checkpointFile);
    if expectedScans ~= 52 || scansThisInvocation < maxScansPerInvocation
        error('run_center_regression:InputCoverage', ...
            'Cannot complete 52 scans: metadata=%d rows=%d newly processed=%d; checkpoint retained with %d accumulated failures.', ...
            expectedScans, height(result), scansThisInvocation, failures);
    end
    return;
end
primaryRows = batch_rows_local(rows, '20260902');
for ir = 1:numel(primaryRows)
    row = primaryRows(ir);
    label = sprintf('batch=20260902 raw=%s', char(row.rawName));
    failures = failures + check_local(row.distanceAB_um <= 0.02, ...
        sprintf('C1 %s |A-B|=%.8f expected <=0.02 um', label, row.distanceAB_um));
    failures = failures + check_local(~row.qcA && ~row.qcB, ...
        sprintf('C1 %s qc=[%d %d] expected [0 0]; A:%s B:%s', label, ...
        row.qcA, row.qcB, char(row.reasonsA), char(row.reasonsB)));
    failures = failures + check_local(isfinite(row.finalPeriodErrorA_um) && abs(row.finalPeriodErrorA_um) <= 0.01, ...
        sprintf('C1 %s signed median final period error A=%+.8f expected |error|<=0.01 um (WG mean error=%+.8f)', ...
        label, row.finalPeriodErrorA_um, row.WGPeriodErrorA_um));
    if endsWith(row.rawName, '_1')
        failures = failures + check_local(isfinite(row.dDutyA) && abs(row.dDutyA) <= 0.012, ...
            sprintf('C1 %s dDutyA=%+.8f expected |duty difference|<=0.012', label, row.dDutyA));
    end
end
failures = failures + check_local(height(result) == 52 && expectedScans == 52 && all(result.complete), ...
    sprintf('C2 all inputs processed: rows=%d metadataScans=%d complete=%d expected 52', ...
    height(result), expectedScans, nnz(result.complete)));
primary = result.batch == "20260902";
failures = failures + check_local(nnz(primary) == 12 && ...
    nnz(primary & endsWith(result.rawName, '_1')) == 6 && ...
    nnz(primary & endsWith(result.rawName, '_2')) == 6, ...
    sprintf('C1 primary batch coverage=%d scans, *_1=%d, *_2=%d expected 12,6,6', ...
    nnz(primary), nnz(primary & endsWith(result.rawName, '_1')), nnz(primary & endsWith(result.rawName, '_2'))));
validTimes = result.timeB_s(result.complete & isfinite(result.timeB_s));
meanTime = mean(validTimes);
failures = failures + check_local(numel(validTimes) == 52 && meanTime <= 15, ...
    sprintf('C2 click-free mean=%.6f s expected <=15 s on one thread (%d/52 scans)', meanTime, numel(validTimes)));
keys = result.batch + "/" + result.rawName;
centers = [result.centerAX_um, result.centerAY_um, result.centerBX_um, result.centerBY_um];
snapshotFile = fullfile(outRoot, 'center_regression_centers.mat');
if isfile(snapshotFile)
    try
        prior = load(snapshotFile);
        if isfield(prior, 'sourceText') && isequal(sourceText, prior.sourceText)
            same = isequal(keys, prior.keys) && isequaln(centers, prior.centers) && all(result.complete);
            failures = failures + check_local(same, 'D1 centers exactly identical to previous regression invocation');
            if ~same && isequal(keys, prior.keys) && isequal(size(centers), size(prior.centers))
                for ir = 1:height(result)
                    if ~isequaln(centers(ir, :), prior.centers(ir, :))
                        fprintf('D1 DIFFERENCE %s previous A=[%.17g %.17g] B=[%.17g %.17g] current A=[%.17g %.17g] B=[%.17g %.17g]\n', ...
                            char(keys(ir)), prior.centers(ir, :), centers(ir, :));
                    end
                end
            end
        else
            fprintf('NOT CHECKED D1 numerical source changed; run again to compare this implementation.\n');
        end
    catch exception
        failures = failures + 1;
        fprintf('FAIL D1 previous-run comparison: %s\n', exception.message);
    end
else
    fprintf('NOT CHECKED D1 first invocation; run run_center_regression again to compare exact centers.\n');
end
if all(result.complete) && height(result) == 52
    save(snapshotFile, 'keys', 'centers', 'sourceText');
end
invocationTime_s = toc(runTime);
totalTime_s = previousTime_s + invocationTime_s;
save_checkpoint_local(checkpointFile, rows, failures, sourceText, totalTime_s, true);
meanTotalTime_s = NaN;
if height(result) > 0; meanTotalTime_s = totalTime_s/height(result); end
fprintf('\nRegression finished: %d failed hard checks; invocationTime=%.6f s totalTimeAcrossChunks=%.6f s totalMeanPerScan=%.6f s completePipelineMean=%.6f s; CSV=%s\n', ...
    failures, invocationTime_s, totalTime_s, meanTotalTime_s, mean(result.elapsed_s, 'omitnan'), csvFile);
if failures > 0
    error('run_center_regression:Failed', '%d regression hard checks failed; see %s.', failures, csvFile);
end
fprintf('PASS run_center_regression\n');
end

function sourceText = source_text_local(projectRoot, batches)
sourceFiles = {'functions/center_stripe_coherence.m','functions/find_center_by_stripe_coherence.m', ...
    'functions/polish_center_radial_period.m','functions/optimize_center_by_inphase_coherence.m', ...
    'functions/extract_inphase_duty_vs_radius.m','functions/set_default_batch_options.m', ...
    'functions/design_period.m','functions/build_scan_cfg_from_batch.m', ...
    'tests/run_center_regression.m', ...
    'config/config_batch_20260511.m'};
for ib = 1:numel(batches)
    sourceFiles{end+1} = ['config/config_batch_', batches{ib}, '.m']; %#ok<AGROW>
end
sourceText = cell(size(sourceFiles));
for ifile = 1:numel(sourceFiles)
    sourceText{ifile} = fileread(fullfile(projectRoot, sourceFiles{ifile}));
end
end

function save_checkpoint_local(checkpointFile, rows, failures, sourceText, accumulatedTime_s, finished)
save(checkpointFile, 'rows', 'failures', 'sourceText', 'accumulatedTime_s', 'finished');
end

function found = has_row_local(rows, batch, rawName)
found = false;
for ir = 1:numel(rows)
    if rows(ir).batch == string(batch) && rows(ir).rawName == string(rawName)
        found = true;
        return;
    end
end
end

function selected = batch_rows_local(rows, batch)
mask = false(size(rows));
for ir = 1:numel(rows)
    mask(ir) = rows(ir).batch == string(batch);
end
selected = rows(mask);
end

function row = empty_row_local()
row = struct('batch', "", 'rawName', "", 'R0_um', NaN, 'LambdaRef_um', NaN, ...
    'manualX_um', NaN, 'manualY_um', NaN, 'referenceX_um', NaN, 'referenceY_um', NaN, ...
    'centerAX_um', NaN, 'centerAY_um', NaN, 'centerBX_um', NaN, 'centerBY_um', NaN, ...
    'distanceAB_um', NaN, 'coherenceA', NaN, 'coherenceB', NaN, ...
    'finalCoherenceA', NaN, 'finalCoherenceB', NaN, ...
    'peakRatioA', NaN, 'peakRatioB', NaN, 'polishTA_um', NaN, 'polishTB_um', NaN, ...
    'polishAppliedA', false, 'polishAppliedB', false, 'polishReasonA', "", 'polishReasonB', "", ...
    'agreeFractionA', NaN, 'finalPeriodErrorA_um', NaN, ...
    'qcA', true, 'qcB', true, 'reasonsA', "", 'reasonsB', "", ...
    'qcNotesA', "", 'qcNotesB', "", ...
    'WGPeriodErrorReference_um', NaN, 'WGPeriodErrorA_um', NaN, ...
    'WGDutyReference', NaN, 'WGDutyA', NaN, 'WGDutyB', NaN, 'dDutyA', NaN, ...
    'WGNPeriodsReference', NaN, 'WGNPeriodsA', NaN, 'referenceArcCrossedSeam', false, ...
    'timeA_s', NaN, 'timeB_s', NaN, 'elapsed_s', NaN, 'reading', "", 'complete', false, 'error', "");
end

function crossed = seam_crossed_local(data, center, radius, cfg)
nTheta = cfg.arc.nTheta;
if ~isempty(cfg.arc.ds_um) && isfinite(cfg.arc.ds_um) && cfg.arc.ds_um > 0
    nTheta = max([nTheta, ceil(2*pi*radius/cfg.arc.ds_um)+1, 1000]);
end
theta = linspace(-pi, pi, nTheta);
xq = center(1)+radius*cos(theta);
yq = center(2)+radius*sin(theta);
x = data.X(1, :);
y = data.Y(:, 1).';
values = interp2(x, y, data.inphase, xq, yq, 'linear', NaN);
valid = isfinite(values) & xq >= min(x) & xq <= max(x) & yq >= min(y) & yq <= max(y);
crossed = valid(1) && valid(end) && ~all(valid);
end

function reading = reading_local(optA, optB, distance, dutyDifference, referenceSeam)
parts = strings(0, 1);
if optA.qc.flag; parts(end+1, 1) = "manual-start QC: " + reasons_text_local(optA.qc.reasons); end
if optB.qc.flag; parts(end+1, 1) = "click-free QC: " + reasons_text_local(optB.qc.reasons); end
if ~isempty(optA.qc.notes); parts(end+1, 1) = "manual-start note: " + reasons_text_local(optA.qc.notes); end
if ~isempty(optB.qc.notes); parts(end+1, 1) = "click-free note: " + reasons_text_local(optB.qc.notes); end
if distance > 0.02
    coherenceDistance = norm(optA.centerCoherence-optB.centerCoherence);
    if coherenceDistance > 0.02
        parts(end+1, 1) = sprintf('coherence centers differ by %.5f um; inspect competing maxima or local window', coherenceDistance);
    else
        parts(end+1, 1) = "coherence centers agree closely; compare radial zero-crossing responses and applied shifts";
    end
end
if ~optA.qc.flag && ~optB.qc.flag && abs(dutyDifference) > 0.03
    parts(end+1, 1) = sprintf('unflagged duty difference from reference is %+.5f; reference arc crossed seam=%d; inspect center and sampled domain support', ...
        dutyDifference, referenceSeam);
end
reading = reasons_text_local(parts);
end

function value = reasons_text_local(reasons)
if isempty(reasons); value = ""; else; value = strjoin(string(reasons(:).'), '; '); end
end

function summarize_batch_local(rows, batch)
if isempty(rows)
    fprintf('BATCH SUMMARY %s count=0\n', batch);
    return;
end
T = struct2table(rows);
duty = T.dDutyA(isfinite(T.dDutyA));
distance = T.distanceAB_um(isfinite(T.distanceAB_um));
maxDuty = NaN; rmsDuty = NaN; maxDistance = NaN;
if ~isempty(duty); maxDuty = max(abs(duty)); rmsDuty = sqrt(mean(duty.^2)); end
if ~isempty(distance); maxDistance = max(distance); end
fprintf('BATCH SUMMARY %s count=%d completed=%d flaggedA=%d flaggedB=%d flaggedEither=%d max|dDutyA|=%.8f rms(dDutyA)=%.8f max|A-B|=%.8f meanTimeA=%.4f s meanTimeB=%.4f s completePipelineTotal=%.4f s completePipelineMean=%.4f s\n', ...
    batch, height(T), nnz(T.complete), nnz(T.qcA), nnz(T.qcB), nnz(T.qcA | T.qcB), ...
    maxDuty, rmsDuty, maxDistance, mean(T.timeA_s, 'omitnan'), mean(T.timeB_s, 'omitnan'), ...
    sum(T.elapsed_s, 'omitnan'), mean(T.elapsed_s, 'omitnan'));
end

function failed = check_local(condition, message)
failed = ~logical(condition);
if failed; status = 'FAIL'; else; status = 'PASS'; end
fprintf('%s %s\n', status, message);
end
