function output = plot_raw_phase_inphase_heatmaps(batchCfg)
%PLOT_RAW_PHASE_INPHASE_HEATMAPS Save raw phase/inphase QC heatmaps.
%
% For every NanoScope TXT export in the batch raw folder, this function:
%   - reads LS_PR_Phase and the first LS_PR_Inphase channel directly;
%   - saves one side-by-side phase/inphase PNG;
%   - saves one overview PNG per device;
%   - writes raw channel statistics to CSV.
%
% No wrapping, smoothing, centering, or signal normalization is applied.

batchCfg = set_default_batch_options(batchCfg);

rawRoot = batchCfg.paths.rawTxtRoot;
if ~isfolder(rawRoot)
    error('Raw TXT root does not exist: %s', rawRoot);
end

rawExt = get_nested_field(batchCfg, 'naming.rawFileExt', '.txt');
if ~startsWith(rawExt, '.')
    rawExt = ['.', rawExt];
end

files = dir(fullfile(rawRoot, ['*', rawExt]));
if isempty(files)
    error('No %s files found in: %s', rawExt, rawRoot);
end

[~, order] = sort(lower(string({files.name})));
files = files(order);

resolution = get_nested_field(batchCfg, 'rawHeatmap.resolution', 180);
inphasePercentile = get_nested_field( ...
    batchCfg, 'rawHeatmap.inphaseAbsPercentile', 99.5);
phaseCLim = get_nested_field(batchCfg, 'rawHeatmap.phaseCLim', [-180, 180]);

if ~isscalar(inphasePercentile) || ~isfinite(inphasePercentile) || ...
        inphasePercentile <= 0 || inphasePercentile > 100
    error('rawHeatmap.inphaseAbsPercentile must be in (0, 100].');
end
if numel(phaseCLim) ~= 2 || any(~isfinite(phaseCLim)) || diff(phaseCLim) <= 0
    error('rawHeatmap.phaseCLim must be a finite increasing two-element vector.');
end

outputRoot = fullfile(batchCfg.paths.resultRoot, 'raw_qc');
individualRoot = fullfile(outputRoot, 'figures', 'individual');
overviewRoot = fullfile(outputRoot, 'figures', 'overview');
ensure_dir(individualRoot);
ensure_dir(overviewRoot);

nFile = numel(files);
phaseMaps = cell(nFile, 1);
inphaseMaps = cell(nFile, 1);
scanInfo = cell(nFile, 1);
rawName = strings(nFile, 1);
fileName = strings(nFile, 1);
deviceID = strings(nFile, 1);
batchIncluded = false(nFile, 1);

fileBytes = nan(nFile, 1);
nx = nan(nFile, 1);
ny = nan(nFile, 1);
scanX_um = nan(nFile, 1);
scanY_um = nan(nFile, 1);
phaseMin_deg = nan(nFile, 1);
phaseMax_deg = nan(nFile, 1);
phaseMean_deg = nan(nFile, 1);
phaseStd_deg = nan(nFile, 1);
phaseP01_deg = nan(nFile, 1);
phaseP99_deg = nan(nFile, 1);
phaseNaNFraction = nan(nFile, 1);
phaseOutOfCLimFraction = nan(nFile, 1);
inphaseMin_V = nan(nFile, 1);
inphaseMax_V = nan(nFile, 1);
inphaseMean_V = nan(nFile, 1);
inphaseMedian_V = nan(nFile, 1);
inphaseStd_V = nan(nFile, 1);
inphaseP01_V = nan(nFile, 1);
inphaseP99_V = nan(nFile, 1);
inphaseNaNFraction = nan(nFile, 1);
inphaseDisplayAbsCLim_V = nan(nFile, 1);
deviceDisplayAbsCLim_V = nan(nFile, 1);
duplicateInphasePresent = false(nFile, 1);
duplicateInphaseMaxAbsDiff_V = nan(nFile, 1);

fprintf('\n========================================\n');
fprintf('Raw phase/inphase heatmap QC\n');
fprintf('Batch: %s\n', batchCfg.batchName);
fprintf('Raw folder: %s\n', rawRoot);
fprintf('TXT files: %d\n', nFile);
fprintf('========================================\n\n');

for ii = 1:nFile
    filePath = fullfile(files(ii).folder, files(ii).name);
    [~, baseName, ~] = fileparts(files(ii).name);

    fprintf('[%02d/%02d] Reading %s\n', ii, nFile, files(ii).name);
    [D, info] = read_pfm_txt_nanoscope_legacy(filePath, batchCfg);

    requiredFields = {'LS_PR_Phase', 'LS_PR_Inphase'};
    missingFields = requiredFields(~isfield(D, requiredFields));
    if ~isempty(missingFields)
        error('Missing required field(s) in %s: %s', ...
            files(ii).name, strjoin(missingFields, ', '));
    end

    phase = double(D.LS_PR_Phase);
    inphase = double(D.LS_PR_Inphase);
    if ~isequal(size(phase), size(inphase))
        error('Phase/inphase size mismatch in %s.', files(ii).name);
    end

    phaseMaps{ii} = phase;
    inphaseMaps{ii} = inphase;
    scanInfo{ii} = info;
    rawName(ii) = string(baseName);
    fileName(ii) = string(files(ii).name);
    deviceID(ii) = infer_device_id(baseName);
    batchIncluded(ii) = ~isempty(regexp( ...
        baseName, batchCfg.naming.rawFilePattern, 'once'));
    fileBytes(ii) = files(ii).bytes;

    [ny(ii), nx(ii)] = size(phase);
    scanX_um(ii) = info.scanX_um;
    scanY_um(ii) = info.scanY_um;

    phaseStats = numeric_stats(phase);
    phaseMin_deg(ii) = phaseStats.min;
    phaseMax_deg(ii) = phaseStats.max;
    phaseMean_deg(ii) = phaseStats.mean;
    phaseStd_deg(ii) = phaseStats.std;
    phaseP01_deg(ii) = phaseStats.p01;
    phaseP99_deg(ii) = phaseStats.p99;
    phaseNaNFraction(ii) = phaseStats.nanFraction;
    phaseFinite = phase(isfinite(phase));
    if ~isempty(phaseFinite)
        phaseOutOfCLimFraction(ii) = mean( ...
            phaseFinite < phaseCLim(1) | phaseFinite > phaseCLim(2));
    end

    inphaseStats = numeric_stats(inphase);
    inphaseMin_V(ii) = inphaseStats.min;
    inphaseMax_V(ii) = inphaseStats.max;
    inphaseMean_V(ii) = inphaseStats.mean;
    inphaseMedian_V(ii) = inphaseStats.median;
    inphaseStd_V(ii) = inphaseStats.std;
    inphaseP01_V(ii) = inphaseStats.p01;
    inphaseP99_V(ii) = inphaseStats.p99;
    inphaseNaNFraction(ii) = inphaseStats.nanFraction;
    inphaseDisplayAbsCLim_V(ii) = robust_abs_limit( ...
        inphase, inphasePercentile);

    duplicateInphasePresent(ii) = isfield(D, 'LS_PR_Inphase_1');
    if duplicateInphasePresent(ii)
        delta = abs(double(D.LS_PR_Inphase_1) - inphase);
        delta = delta(isfinite(delta));
        if isempty(delta)
            duplicateInphaseMaxAbsDiff_V(ii) = NaN;
        else
            duplicateInphaseMaxAbsDiff_V(ii) = max(delta);
        end
    end

    clear D phase inphase;
end

deviceList = unique(deviceID, 'stable');
for dd = 1:numel(deviceList)
    rows = deviceID == deviceList(dd);
    values = collect_finite_abs(inphaseMaps(rows));
    deviceLimit = percentile_from_sorted(values, inphasePercentile);
    deviceLimit = ensure_positive_limit(deviceLimit, values);
    deviceDisplayAbsCLim_V(rows) = deviceLimit;
end

stats = table(rawName, fileName, deviceID, batchIncluded, fileBytes, nx, ny, ...
    scanX_um, scanY_um, ...
    phaseMin_deg, phaseMax_deg, phaseMean_deg, phaseStd_deg, ...
    phaseP01_deg, phaseP99_deg, phaseNaNFraction, ...
    phaseOutOfCLimFraction, ...
    inphaseMin_V, inphaseMax_V, inphaseMean_V, inphaseMedian_V, ...
    inphaseStd_V, inphaseP01_V, inphaseP99_V, inphaseNaNFraction, ...
    inphaseDisplayAbsCLim_V, deviceDisplayAbsCLim_V, ...
    duplicateInphasePresent, duplicateInphaseMaxAbsDiff_V);

statsPath = fullfile(outputRoot, 'raw_heatmap_stats.csv');
writetable(stats, statsPath);

individualPaths = strings(nFile, 1);
for ii = 1:nFile
    pngPath = fullfile(individualRoot, ...
        sprintf('%s_raw_phase_inphase.png', rawName(ii)));
    plot_individual_pair(phaseMaps{ii}, inphaseMaps{ii}, scanInfo{ii}, ...
        rawName(ii), batchIncluded(ii), phaseCLim, inphaseDisplayAbsCLim_V(ii), ...
        inphaseMin_V(ii), inphaseMax_V(ii), pngPath, resolution);
    individualPaths(ii) = string(pngPath);
end

overviewPaths = strings(numel(deviceList), 1);
for dd = 1:numel(deviceList)
    rows = find(deviceID == deviceList(dd));
    safeDevice = regexprep(char(deviceList(dd)), '[^a-zA-Z0-9_-]', '_');
    pngPath = fullfile(overviewRoot, ...
        sprintf('%s_raw_phase_inphase_overview.png', safeDevice));
    plot_device_overview(phaseMaps(rows), inphaseMaps(rows), scanInfo(rows), ...
        rawName(rows), deviceList(dd), phaseCLim, ...
        deviceDisplayAbsCLim_V(rows(1)), inphaseMin_V(rows), ...
        inphaseMax_V(rows), pngPath, resolution);
    overviewPaths(dd) = string(pngPath);
end

fprintf('\nRaw QC outputs written:\n');
fprintf('  Statistics: %s\n', statsPath);
fprintf('  Individual figures: %s (%d PNGs)\n', individualRoot, nFile);
fprintf('  Device overviews: %s (%d PNGs)\n\n', ...
    overviewRoot, numel(deviceList));

output = struct();
output.outputRoot = outputRoot;
output.statsPath = statsPath;
output.individualPaths = individualPaths;
output.overviewPaths = overviewPaths;
output.stats = stats;

end

function plot_individual_pair(phase, inphase, info, rawName, batchIncluded, phaseCLim, ...
        inphaseLimit, inphaseMin, inphaseMax, pngPath, resolution)
    fig = figure('Color', 'w', 'Visible', 'off', 'WindowStyle', 'normal');
    set(fig, 'Units', 'pixels', 'Position', [100, 100, 1500, 680]);
    try
        layout = tiledlayout(fig, 1, 2, ...
            'TileSpacing', 'compact', 'Padding', 'compact');

        axPhase = nexttile(layout);
        draw_phase_axis(axPhase, phase, info, phaseCLim, ...
            'Raw LS_PR_Phase');

        axInphase = nexttile(layout);
        draw_inphase_axis(axInphase, inphase, info, inphaseLimit, ...
            sprintf('Raw LS_PR_Inphase | raw [%.4g, %.4g] V', ...
            inphaseMin, inphaseMax));

        if batchIncluded
            batchLabel = 'batch included';
        else
            batchLabel = 'excluded reference';
        end
        titleText = sprintf( ...
            '%s | %d x %d px | %.4g x %.4g um | %s | no signal processing', ...
            rawName, size(phase, 2), size(phase, 1), ...
            info.scanX_um, info.scanY_um, batchLabel);
        title(layout, titleText, 'Interpreter', 'none', 'FontWeight', 'bold');

        exportgraphics(fig, pngPath, 'Resolution', resolution);
        close(fig);
    catch ME
        if isgraphics(fig)
            close(fig);
        end
        rethrow(ME);
    end
end

function plot_device_overview(phaseMaps, inphaseMaps, infoList, rawNames, ...
        deviceID, phaseCLim, inphaseLimit, inphaseMins, inphaseMaxs, ...
        pngPath, resolution)
    nScan = numel(phaseMaps);
    figHeight = max(700, 330 * nScan);
    fig = figure('Color', 'w', 'Visible', 'off', 'WindowStyle', 'normal');
    set(fig, 'Units', 'pixels', 'Position', [100, 50, 1500, figHeight]);
    try
        layout = tiledlayout(fig, nScan, 2, ...
            'TileSpacing', 'compact', 'Padding', 'compact');

        for ii = 1:nScan
            axPhase = nexttile(layout);
            draw_phase_axis(axPhase, phaseMaps{ii}, infoList{ii}, phaseCLim, ...
                sprintf('%s | raw phase', rawNames(ii)));

            axInphase = nexttile(layout);
            draw_inphase_axis(axInphase, inphaseMaps{ii}, infoList{ii}, ...
                inphaseLimit, sprintf('%s | raw inphase [%.4g, %.4g] V', ...
                rawNames(ii), inphaseMins(ii), inphaseMaxs(ii)));
        end

        title(layout, sprintf('%s raw-channel QC | common inphase CLim +/-%.4g V', ...
            deviceID, inphaseLimit), ...
            'Interpreter', 'none', 'FontWeight', 'bold');

        exportgraphics(fig, pngPath, 'Resolution', resolution);
        close(fig);
    catch ME
        if isgraphics(fig)
            close(fig);
        end
        rethrow(ME);
    end
end

function draw_phase_axis(ax, phase, info, phaseCLim, titleText)
    x = linspace(0, info.scanX_um, size(phase, 2));
    y = linspace(0, info.scanY_um, size(phase, 1));
    imagesc(ax, x, y, phase);
    axis(ax, 'image');
    set(ax, 'YDir', 'normal');
    clim(ax, phaseCLim);
    colormap(ax, hsv(256));
    cb = colorbar(ax);
    cb.Label.String = 'Phase (deg)';
    xlabel(ax, 'x (um)');
    ylabel(ax, 'y (um)');
    title(ax, titleText, 'Interpreter', 'none');
end

function draw_inphase_axis(ax, inphase, info, inphaseLimit, titleText)
    x = linspace(0, info.scanX_um, size(inphase, 2));
    y = linspace(0, info.scanY_um, size(inphase, 1));
    imagesc(ax, x, y, inphase);
    axis(ax, 'image');
    set(ax, 'YDir', 'normal');
    clim(ax, [-inphaseLimit, inphaseLimit]);
    colormap(ax, diverging_map(256));
    cb = colorbar(ax);
    cb.Label.String = 'Inphase (V)';
    xlabel(ax, 'x (um)');
    ylabel(ax, 'y (um)');
    title(ax, titleText, 'Interpreter', 'none');
end

function stats = numeric_stats(A)
    finiteValues = double(A(isfinite(A)));
    stats = struct('min', NaN, 'max', NaN, 'mean', NaN, ...
        'median', NaN, 'std', NaN, 'p01', NaN, 'p99', NaN, ...
        'nanFraction', 1 - numel(finiteValues) / numel(A));
    if isempty(finiteValues)
        return;
    end

    sorted = sort(finiteValues);
    stats.min = sorted(1);
    stats.max = sorted(end);
    stats.mean = mean(finiteValues);
    stats.median = median(finiteValues);
    stats.std = std(finiteValues);
    stats.p01 = percentile_from_sorted(sorted, 1);
    stats.p99 = percentile_from_sorted(sorted, 99);
end

function limit = robust_abs_limit(A, percentile)
    values = abs(double(A(isfinite(A))));
    values = sort(values);
    limit = percentile_from_sorted(values, percentile);
    limit = ensure_positive_limit(limit, values);
end

function values = collect_finite_abs(mapCells)
    values = cellfun(@(A) abs(double(A(isfinite(A)))), ...
        mapCells, 'UniformOutput', false);
    values = sort(vertcat(values{:}));
end

function value = percentile_from_sorted(sortedValues, percentile)
    if isempty(sortedValues)
        value = NaN;
        return;
    end
    sortedValues = sort(sortedValues(:));
    position = 1 + (numel(sortedValues) - 1) * percentile / 100;
    lo = floor(position);
    hi = ceil(position);
    if lo == hi
        value = sortedValues(lo);
    else
        weight = position - lo;
        value = sortedValues(lo) * (1 - weight) + sortedValues(hi) * weight;
    end
end

function limit = ensure_positive_limit(limit, values)
    if isfinite(limit) && limit > 0
        return;
    end
    if isempty(values)
        limit = 1;
        return;
    end
    fallback = max(values);
    if ~isfinite(fallback) || fallback <= 0
        fallback = 1;
    end
    limit = fallback;
end

function deviceID = infer_device_id(baseName)
    tok = regexp(baseName, ...
        '^(?<prefix>.+)_R(?<row>\d+)C(?<col>\d+)_\d+$', ...
        'names', 'once', 'ignorecase');
    if isempty(tok)
        deviceID = string(baseName);
    else
        deviceID = string(sprintf('%s_r%dc%d', tok.prefix, ...
            str2double(tok.row), str2double(tok.col)));
    end
end

function map = diverging_map(n)
    anchors = [0.10, 0.25, 0.85; ...
               1.00, 1.00, 1.00; ...
               0.80, 0.10, 0.10];
    map = interp1([0, 0.5, 1], anchors, linspace(0, 1, n), 'linear');
end

function ensure_dir(pathValue)
    if ~exist(pathValue, 'dir')
        mkdir(pathValue);
    end
end
