function test_arc_seam()
%TEST_ARC_SEAM Check seam joining and bit-identical non-seam extraction.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
oldPath = path;
pathCleanup = onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(fullfile(projectRoot, 'functions'), fullfile(projectRoot, 'config'));
outRoot = fullfile(projectRoot, 'local', 'regression_out');
baselineRoot = fullfile(outRoot, 'arc_seam_baseline');
if ~isfolder(baselineRoot); mkdir(baselineRoot); end
addpath(baselineRoot);
nFail = 0;
names = {'extract_inphase_duty_vs_radius', 'extract_period_duty_vs_radius'};
baselineReady = false(1, numel(names));
for k = 1:numel(names)
    try
        cmd = sprintf('git -c safe.directory="%s" -C "%s" show HEAD:functions/%s.m', ...
            strrep(projectRoot, '\', '/'), projectRoot, names{k});
        [status, source] = system(cmd);
        if status ~= 0; error('git show failed (status %d): %s', status, source); end
        source = strrep(source, ['function analysis = ', names{k}, '('], ...
            ['function analysis = baseline_', names{k}, '(']);
        fid = fopen(fullfile(baselineRoot, ['baseline_', names{k}, '.m']), 'w');
        if fid < 0; error('Cannot write baseline for %s.', names{k}); end
        fileCleanup = onCleanup(@() fclose(fid));
        fprintf(fid, '%s', source);
        clear fileCleanup;
        baselineReady(k) = true;
        fprintf('PASS baseline saved from HEAD: %s\n', names{k});
    catch err
        nFail = nFail + fail_local(['baseline ', names{k}], err);
    end
end
rehash;

try
    batchCfg = config_batch_20260902();
    batchRoot = fullfile(projectRoot, 'local', 'batches', '20260902');
    batchCfg.paths.rawTxtRoot = fullfile(batchRoot, 'raw');
    batchCfg.paths.processedRoot = fullfile(outRoot, 'arc_seam_processed');
    batchCfg.paths.figureRoot = fullfile(outRoot, 'arc_seam_figures');
    batchCfg.metadata.designsFile = fullfile(batchRoot, 'metadata', 'designs.csv');
    batchCfg.metadata.devicesFile = fullfile(batchRoot, 'metadata', 'devices.csv');
    batchCfg.metadata.scansFile = fullfile(batchRoot, 'metadata', 'scans.csv');
    meta = read_batch_metadata(batchCfg);
    reference = readtable(fullfile(projectRoot, 'local', 'reference', '20260902', ...
        'batch_summary_20260902_inphase.csv'), 'TextType', 'string');
    nOne = sum(endsWith(string(meta.scans.rawName), '_1'));
    nTwo = sum(endsWith(string(meta.scans.rawName), '_2'));
    nFail = nFail + check_local(nOne == 6 && nTwo == 6, ...
        sprintf('A data coverage: *_1=%d *_2=%d expected=6 each', nOne, nTwo));
    for k = 1:height(meta.scans)
        rawName = char(meta.scans.rawName(k));
        try
            scanRow = meta.scans(k,:);
            deviceIdx = find(meta.devices.deviceID == scanRow.deviceID, 1, 'first');
            if isempty(deviceIdx); error('Missing device row for %s.', rawName); end
            deviceRow = meta.devices(deviceIdx,:);
            designRow = get_design_row(meta, deviceRow.designID);
            cfg = build_scan_cfg_from_batch(batchCfg, deviceRow, scanRow, designRow);
            refIdx = find(string(reference.rawName) == string(rawName), 1, 'first');
            if isempty(refIdx); error('Missing reference row for %s.', rawName); end
            center = [reference.centerOptimizedX_um(refIdx), reference.centerOptimizedY_um(refIdx)];
            rawFile = fullfile(batchCfg.paths.rawTxtRoot, rawName);
            [~,~,ext] = fileparts(rawFile);
            if isempty(ext); rawFile = [rawFile, '.txt']; end
            [D, rawInfo] = read_pfm_txt_nanoscope_legacy(rawFile, cfg);
            [X,Y] = meshgrid(linspace(0, rawInfo.scanX_um, rawInfo.nx), ...
                linspace(0, rawInfo.scanY_um, rawInfo.ny));
            data = struct('X', X, 'Y', Y, 'inphase', D.LS_PR_Inphase, 'phase', D.LS_PR_Phase);
            fprintf('SCAN %s referenceCenter=[%.12g %.12g] R0=%.12g\n', ...
                rawName, center(1), center(2), cfg.design.R0);
        catch err
            nFail = nFail + fail_local(['input ', rawName], err);
            continue;
        end
        if endsWith(rawName, '_1')
            rList = cfg.radius.rMin:cfg.radius.dr:cfg.radius.rMax;
            for basis = 1:2
                try
                    if ~baselineReady(basis); error('Baseline was not created.'); end
                    actual = feval(names{basis}, data, center, rList, cfg);
                    expected = feval(['baseline_', names{basis}], data, center, rList, cfg);
                    nFail = nFail + compare_local(expected, actual, ...
                        sprintf('A1 %s %s', rawName, names{basis}));
                catch err
                    nFail = nFail + fail_local(sprintf('A1 %s %s', rawName, names{basis}), err);
                end
            end
        elseif endsWith(rawName, '_2')
            for basis = 1:2
                try
                    actual = feval(names{basis}, data, center, cfg.design.R0, cfg);
                    nFail = nFail + check_arc_local(actual.arc(1), data, center, cfg.design.R0, cfg, ...
                        sprintf('A2 %s %s', rawName, names{basis}));
                catch err
                    nFail = nFail + fail_local(sprintf('A2 %s %s', rawName, names{basis}), err);
                end
            end
        end
    end
catch err
    nFail = nFail + fail_local('real-data seam setup', err);
end

try
    [X,Y] = meshgrid(linspace(0, 30, 256));
    center = [15, 15];
    theta = atan2(Y-center(2), X-center(1));
    low = mod(12*theta/(2*pi), 1) < 0.35;
    data = struct('X', X, 'Y', Y, 'inphase', 1-2*double(low), ...
        'phase', 90-180*double(low));
    cfg = set_default_batch_options(struct());
    cfg.arc.edgeTrimFraction = 0;
    for basis = 1:2
        try
            if ~baselineReady(basis); error('Baseline was not created.'); end
            actual = feval(names{basis}, data, center, [3, 5, 8], cfg);
            expected = feval(['baseline_', names{basis}], data, center, [3, 5, 8], cfg);
            nFail = nFail + compare_local(expected, actual, ['A1 full circle ', names{basis}]);
            nFail = nFail + check_local(isequaln(expected.arc, actual.arc), ...
                ['A1 full-circle arc bit equality ', names{basis}]);
        catch err
            nFail = nFail + fail_local(['A1 full circle ', names{basis}], err);
        end
    end
catch err
    nFail = nFail + fail_local('synthetic full-circle setup', err);
end
fprintf('test_arc_seam: hard failures=%d\n', nFail);
if nFail > 0; error('test_arc_seam:Failed', '%d hard seam checks failed.', nFail); end
fprintf('PASS test_arc_seam\n');
end

function nFail = compare_local(expected, actual, label)
fields = {'periodMean', 'periodStd', 'dutyMean', 'dutyStd', 'nPeriods'};
nFail = 0;
for k = 1:numel(fields)
    field = fields{k};
    same = isequaln(expected.(field), actual.(field));
    nFail = nFail + check_local(same, sprintf('%s %s bit equality, radii=%d', ...
        label, field, numel(expected.(field))));
    if ~same
        fprintf('  expected=%s\n  actual  =%s\n', ...
            mat2str(expected.(field), 16), mat2str(actual.(field), 16));
    end
end
end

function nFail = check_arc_local(arc, data, center, radius, cfg, label)
nFail = 0;
theta = linspace(-pi, pi, 200001);
x = center(1) + radius*cos(theta);
y = center(2) + radius*sin(theta);
visible = x >= min(data.X(:)) & x <= max(data.X(:)) & ...
    y >= min(data.Y(:)) & y <= max(data.Y(:));
visibleLength = radius*(theta(2)-theta(1))*sum(visible(1:end-1));
minimumLength = 0.9*visibleLength*(1-2*cfg.arc.edgeTrimFraction);
nTheta = cfg.arc.nTheta;
if ~isempty(cfg.arc.ds_um) && isfinite(cfg.arc.ds_um) && cfg.arc.ds_um > 0
    nTheta = max([nTheta, ceil(2*pi*radius/cfg.arc.ds_um)+1, 1000]);
end
gridStep = 2*pi/(nTheta-1);
nonempty = numel(arc.s) >= 2;
nFail = nFail + check_local(nonempty, [label, ' nonempty arc']);
if ~nonempty; return; end
onePiece = all(diff(arc.theta) > 0) && all(diff(arc.theta) <= gridStep*(1+1e-8));
nFail = nFail + check_local(onePiece, sprintf('%s one piece, maxThetaStep=%.12g gridStep=%.12g', ...
    label, max(diff(arc.theta)), gridStep));
nFail = nFail + check_local(all(diff(arc.s) > 0), ...
    sprintf('%s strictly increasing s, minStep=%.12g', label, min(diff(arc.s))));
xy = round([arc.x(:), arc.y(:)]/1e-9);
nUnique = size(unique(xy, 'rows'), 1);
nFail = nFail + check_local(nUnique == numel(arc.s), ...
    sprintf('%s no duplicate physical point (1e-9 um), unique=%d samples=%d', ...
    label, nUnique, numel(arc.s)));
lengthUsed = arc.s(end)-arc.s(1);
nFail = nFail + check_local(lengthUsed >= minimumLength, ...
    sprintf('%s length=%.12g minimum=%.12g visible=%.12g', ...
    label, lengthUsed, minimumLength, visibleLength));
end

function nFail = check_local(condition, label)
nFail = double(~condition);
if condition; fprintf('PASS %s\n', label); else; fprintf('FAIL %s\n', label); end
end

function nFail = fail_local(label, err)
nFail = 1;
fprintf('FAIL %s: %s\n', label, getReport(err, 'extended', 'hyperlinks', 'off'));
end
