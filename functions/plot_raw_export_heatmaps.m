function output = plot_raw_export_heatmaps(batchCfg)
%PLOT_RAW_EXPORT_HEATMAPS Plot every matrix in each NanoScope TXT export.
%
% This is a plot-only workflow. Exported values are read and displayed
% directly: no wrapping, smoothing, centering, normalization, or other
% signal processing is applied.

batchCfg = set_default_batch_options(batchCfg);

rawRoot = batchCfg.paths.rawTxtRoot;
if ~isfolder(rawRoot)
    error('Raw TXT root does not exist: %s', rawRoot);
end

rawExt = get_nested_field(batchCfg, 'rawHeatmap.rawExt', ...
    get_nested_field(batchCfg, 'naming.rawFileExt', '.txt'));
if ~startsWith(rawExt, '.')
    rawExt = ['.', rawExt];
end

files = dir(fullfile(rawRoot, ['*', rawExt]));
if isempty(files)
    error('No %s files found in: %s', rawExt, rawRoot);
end
[~, order] = sort(lower(string({files.name})));
files = files(order);

readerMode = get_nested_field(batchCfg, 'rawHeatmap.reader', 'pfm_legacy');
headerTokens = get_nested_field(batchCfg, 'rawHeatmap.headerTokens', {});

resolution = get_nested_field(batchCfg, 'rawHeatmap.resolution', ...
    batchCfg.plot.resolution);
phaseCLim = get_nested_field(batchCfg, 'rawHeatmap.phaseCLim', ...
    batchCfg.plot.phaseCLim);
saveOverview = get_nested_field(batchCfg, 'rawHeatmap.saveOverview', true);
requestedChannels = get_nested_field(batchCfg, 'rawHeatmap.channels', {});

if ~isscalar(resolution) || ~isfinite(resolution) || resolution <= 0
    error('rawHeatmap.resolution must be a positive finite scalar.');
end
if numel(phaseCLim) ~= 2 || any(~isfinite(phaseCLim)) || diff(phaseCLim) <= 0
    error('rawHeatmap.phaseCLim must be a finite increasing two-element vector.');
end
if isstring(requestedChannels)
    requestedChannels = cellstr(requestedChannels);
end
if ~iscell(requestedChannels)
    error('rawHeatmap.channels must be a cell array or string array.');
end

outputRoot = get_nested_field(batchCfg, 'rawHeatmap.outputRoot', ...
    fullfile(batchCfg.paths.resultRoot, 'raw_qc'));
channelRoot = fullfile(outputRoot, 'figures', 'channels');
overviewRoot = fullfile(outputRoot, 'figures', 'overview');
ensure_dir(channelRoot);
if saveOverview
    ensure_dir(overviewRoot);
end

manifestRows = repmat(empty_manifest_row(), 0, 1);
individualPaths = strings(0, 1);
overviewPaths = strings(0, 1);

fprintf('\n========================================\n');
fprintf('Raw exported-channel heatmaps\n');
fprintf('Batch: %s\n', batchCfg.batchName);
fprintf('Raw folder: %s\n', rawRoot);
fprintf('TXT files: %d\n', numel(files));
fprintf('Signal processing: none\n');
fprintf('========================================\n\n');

for ii = 1:numel(files)
    filePath = fullfile(files(ii).folder, files(ii).name);
    [~, baseName, ~] = fileparts(files(ii).name);
    safeBaseName = make_safe_name(baseName);

    fprintf('[%02d/%02d] Reading %s\n', ii, numel(files), files(ii).name);
    switch lower(char(string(readerMode)))
        case {'pfm_legacy', 'legacy', 'nanoscope_legacy'}
            [D, info, raw] = read_pfm_txt_nanoscope_legacy(filePath, batchCfg);
        case {'nanoscope_channels', 'channels'}
            [D, info, raw] = read_nanoscope_txt_channels(filePath, headerTokens);
        otherwise
            error('Unknown rawHeatmap.reader: %s', readerMode);
    end

    [channelFields, sourceHeaders] = select_channels( ...
        raw.colNames, raw.colTokens, requestedChannels);
    if isempty(channelFields)
        error('No requested exported channels found in %s.', files(ii).name);
    end

    fileOutputRoot = fullfile(channelRoot, safeBaseName);
    ensure_dir(fileOutputRoot);
    channelStyles = cell(numel(channelFields), 1);

    for jj = 1:numel(channelFields)
        fieldName = channelFields{jj};
        sourceHeader = sourceHeaders{jj};
        values = double(D.(fieldName));
        unit = infer_channel_unit(sourceHeader, fieldName);
        style = choose_channel_style(values, fieldName, phaseCLim);
        channelStyles{jj} = style;

        pngName = sprintf('%s__%s.png', safeBaseName, ...
            make_safe_name(fieldName));
        pngPath = fullfile(fileOutputRoot, pngName);
        plot_individual_channel(values, info, baseName, fieldName, unit, ...
            style, pngPath, resolution);
        individualPaths(end + 1, 1) = string(pngPath); %#ok<AGROW>

        stats = finite_stats(values);
        row = empty_manifest_row();
        row.rawName = string(baseName);
        row.fileName = string(files(ii).name);
        row.channelIndex = jj;
        row.channelName = string(fieldName);
        row.sourceHeader = string(sourceHeader);
        row.unit = string(unit);
        row.nx = size(values, 2);
        row.ny = size(values, 1);
        row.scanX_um = info.scanX_um;
        row.scanY_um = info.scanY_um;
        row.rawMin = stats.min;
        row.rawMax = stats.max;
        row.rawMean = stats.mean;
        row.nanFraction = stats.nanFraction;
        row.displayCLimMin = style.clim(1);
        row.displayCLimMax = style.clim(2);
        row.colorScale = string(style.scaleName);
        row.outputFile = string(pngPath);
        manifestRows(end + 1, 1) = row; %#ok<AGROW>
    end

    if saveOverview
        overviewPath = fullfile(overviewRoot, ...
            sprintf('%s__all_raw_channels.png', safeBaseName));
        plot_channel_overview(D, channelFields, sourceHeaders, ...
            channelStyles, info, baseName, overviewPath, resolution);
        overviewPaths(end + 1, 1) = string(overviewPath); %#ok<AGROW>
    end

    clear D raw;
end

manifest = struct2table(manifestRows);
manifestPath = fullfile(outputRoot, 'raw_heatmap_manifest.csv');
writetable(manifest, manifestPath);

fprintf('\nRaw heatmap outputs written:\n');
fprintf('  Per-channel heatmaps: %s (%d PNGs)\n', ...
    channelRoot, numel(individualPaths));
if saveOverview
    fprintf('  Per-file overviews: %s (%d PNGs)\n', ...
        overviewRoot, numel(overviewPaths));
end
fprintf('  Manifest: %s\n\n', manifestPath);

output = struct();
output.outputRoot = outputRoot;
output.channelRoot = channelRoot;
output.overviewRoot = overviewRoot;
output.manifestPath = manifestPath;
output.individualPaths = individualPaths;
output.overviewPaths = overviewPaths;
output.manifest = manifest;

end

function [selectedNames, selectedHeaders] = select_channels( ...
        channelNames, sourceHeaders, requestedChannels)
    if isempty(requestedChannels)
        selectedNames = channelNames;
        selectedHeaders = sourceHeaders;
        return;
    end

    keep = false(size(channelNames));
    for ii = 1:numel(requestedChannels)
        requested = char(string(requestedChannels{ii}));
        keep = keep | strcmpi(channelNames, requested) | ...
            strcmpi(sourceHeaders, requested);
    end
    selectedNames = channelNames(keep);
    selectedHeaders = sourceHeaders(keep);

    found = [selectedNames, selectedHeaders];
    missing = requestedChannels;
    for ii = numel(missing):-1:1
        if any(strcmpi(found, char(string(missing{ii}))))
            missing(ii) = [];
        end
    end
    if ~isempty(missing)
        warning('Requested raw channel(s) not found: %s', ...
            strjoin(string(missing), ', '));
    end
end

function plot_individual_channel(values, info, rawName, fieldName, unit, ...
        style, pngPath, resolution)
    fig = figure('Color', 'w', 'Visible', 'off', 'WindowStyle', 'normal');
    set(fig, 'Units', 'pixels', 'Position', [100, 80, 900, 760]);
    try
        ax = axes(fig);
        draw_channel_axis(ax, values, info, fieldName, unit, style);
        title(ax, {sprintf('%s | %s', rawName, fieldName), ...
            sprintf('%d x %d px | %.6g x %.6g um | raw values; no normalization', ...
            size(values, 2), size(values, 1), info.scanX_um, info.scanY_um)}, ...
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

function plot_channel_overview(D, channelFields, sourceHeaders, styles, ...
        info, rawName, pngPath, resolution)
    nChannel = numel(channelFields);
    nCol = min(3, nChannel);
    nRow = ceil(nChannel / nCol);
    fig = figure('Color', 'w', 'Visible', 'off', 'WindowStyle', 'normal');
    set(fig, 'Units', 'pixels', 'Position', ...
        [50, 40, 520 * nCol, 430 * nRow + 90]);
    try
        layout = tiledlayout(fig, nRow, nCol, ...
            'TileSpacing', 'compact', 'Padding', 'compact');
        for ii = 1:nChannel
            fieldName = channelFields{ii};
            unit = infer_channel_unit(sourceHeaders{ii}, fieldName);
            ax = nexttile(layout);
            draw_channel_axis(ax, double(D.(fieldName)), info, ...
                fieldName, unit, styles{ii});
            title(ax, fieldName, 'Interpreter', 'none');
        end
        title(layout, sprintf( ...
            '%s | %d x %d px | %.6g x %.6g um | raw exported values; no normalization', ...
            rawName, info.nx, info.ny, info.scanX_um, info.scanY_um), ...
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

function draw_channel_axis(ax, values, info, fieldName, unit, style)
    x = linspace(0, info.scanX_um, size(values, 2));
    y = linspace(0, info.scanY_um, size(values, 1));
    imagesc(ax, x, y, values);
    axis(ax, 'image');
    set(ax, 'YDir', 'normal', 'Box', 'on');
    clim(ax, style.clim);
    colormap(ax, style.colormap);
    cb = colorbar(ax);
    if isempty(unit)
        cb.Label.String = fieldName;
    else
        cb.Label.String = sprintf('%s (%s)', fieldName, unit);
    end
    cb.Label.Interpreter = 'none';
    xlabel(ax, 'x (\mum)');
    ylabel(ax, 'y (\mum)');
end

function style = choose_channel_style(values, fieldName, phaseCLim)
    finiteValues = values(isfinite(values));
    isPhase = ~isempty(regexp(fieldName, '(^|_)Phase($|_)', 'once'));
    isSignedPFM = contains(fieldName, 'Inphase', 'IgnoreCase', true) || ...
        contains(fieldName, 'Quadrature', 'IgnoreCase', true);

    if isPhase
        limits = phaseCLim;
        map = hsv(256);
        scaleName = 'fixed_phase_range';
    elseif isSignedPFM
        if isempty(finiteValues)
            absLimit = 1;
        else
            absLimit = max(abs(finiteValues));
            if ~isfinite(absLimit) || absLimit <= 0
                absLimit = 1;
            end
        end
        limits = [-absLimit, absLimit];
        map = diverging_map(256);
        scaleName = 'symmetric_full_raw_range';
    else
        limits = full_raw_limits(finiteValues);
        map = parula(256);
        scaleName = 'full_raw_range';
    end

    style = struct('clim', double(limits(:).'), 'colormap', map, ...
        'scaleName', scaleName);
end

function limits = full_raw_limits(finiteValues)
    if isempty(finiteValues)
        limits = [0, 1];
        return;
    end
    limits = [min(finiteValues), max(finiteValues)];
    if diff(limits) <= 0
        pad = max(abs(limits(1)) * 0.01, 0.5);
        limits = limits + [-pad, pad];
    end
end

function unit = infer_channel_unit(sourceHeader, fieldName)
    token = regexp(sourceHeader, '\(([^\)]*)\)', 'tokens', 'once');
    if isempty(token)
        unit = '';
    else
        unit = strtrim(token{1});
    end

    if ~isempty(regexp(fieldName, '(^|_)Phase($|_)', 'once'))
        unit = 'deg';
    elseif contains(unit, char(65533))
        unit = '';
    end
end

function stats = finite_stats(values)
    finiteValues = double(values(isfinite(values)));
    stats = struct('min', NaN, 'max', NaN, 'mean', NaN, ...
        'nanFraction', 1 - numel(finiteValues) / numel(values));
    if isempty(finiteValues)
        return;
    end
    stats.min = min(finiteValues);
    stats.max = max(finiteValues);
    stats.mean = mean(finiteValues);
end

function row = empty_manifest_row()
    row = struct( ...
        'rawName', string(missing), ...
        'fileName', string(missing), ...
        'channelIndex', NaN, ...
        'channelName', string(missing), ...
        'sourceHeader', string(missing), ...
        'unit', string(missing), ...
        'nx', NaN, ...
        'ny', NaN, ...
        'scanX_um', NaN, ...
        'scanY_um', NaN, ...
        'rawMin', NaN, ...
        'rawMax', NaN, ...
        'rawMean', NaN, ...
        'nanFraction', NaN, ...
        'displayCLimMin', NaN, ...
        'displayCLimMax', NaN, ...
        'colorScale', string(missing), ...
        'outputFile', string(missing));
end

function safeName = make_safe_name(name)
    safeName = regexprep(char(string(name)), '[^a-zA-Z0-9_-]', '_');
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
