%% Plot raw phase/inphase heatmaps for the selected historical recipes
% The selection below is the set used to support the historical recipe
% conclusions discussed for 30/50 um radii and 2.5/3.0 um periods.
%
% Outputs:
%   local/comparisons/selected_historical_candidates/raw_qc/
%
% The plotted matrices are the raw LS_PR_Phase and first LS_PR_Inphase
% channels. No wrapping, smoothing, centering, or normalization is applied.

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchName = [ ...
    "20260506"; "20260506"; ...
    "20260511"; "20260511"; ...
    "20260506"; "20260506"; ...
    "20260511"; "20260511"; ...
    "20260511_1"; "20260511_1"; ...
    "20260511_2"; "20260511_2"];

rawName = [ ...
    "E7_R1C6_1"; "E7_R1C6_2"; ...
    "UF_2p5_r1c6_1"; "UF_2p5_r1c6_2"; ...
    "E8_R1C3_1"; "E8_R1C3_2"; ...
    "UF_2p5_r1c1_1"; "UF_2p5_r1c1_2"; ...
    "UF_2p5_r4c1_1"; "UF_2p5_r4c1_2"; ...
    "UF_3p0_r1c1_1"; "UF_3p0_r1c1_2"];

geometry = [ ...
    repmat("R30um_L2p5um", 8, 1); ...
    repmat("R50um_L2p5um", 2, 1); ...
    repmat("R30um_L3p0um", 2, 1)];

recipe = [ ...
    repmat("500_p8", 2, 1); ...
    repmat("520_p6", 2, 1); ...
    repmat("600_p4", 4, 1); ...
    repmat("600_p4", 2, 1); ...
    repmat("600_p4", 2, 1)];

groupID = geometry + "_" + recipe;
selection = table(batchName, rawName, geometry, recipe, groupID);

outputRoot = fullfile(pwd, 'local', 'comparisons', ...
    'selected_historical_candidates', 'raw_qc');
individualRoot = fullfile(outputRoot, 'figures', 'individual');
overviewRoot = fullfile(outputRoot, 'figures', 'overview');
ensure_dir(individualRoot);
ensure_dir(overviewRoot);

phaseCLim = [-180, 180];
inphaseAbsPercentile = 99.5;
resolution = 180;
nScan = height(selection);

phaseMaps = cell(nScan, 1);
inphaseMaps = cell(nScan, 1);
infoList = cell(nScan, 1);
individualDisplayAbsCLim_V = nan(nScan, 1);
groupDisplayAbsCLim_V = nan(nScan, 1);
phaseMin_deg = nan(nScan, 1);
phaseMax_deg = nan(nScan, 1);
inphaseMin_V = nan(nScan, 1);
inphaseMax_V = nan(nScan, 1);
inphaseStd_V = nan(nScan, 1);
individualFigure = strings(nScan, 1);

fprintf('\nSelected historical raw-channel comparison\n');
fprintf('Scans: %d | groups: %d\n', nScan, numel(unique(groupID)));
fprintf('Output root: %s\n\n', outputRoot);

for ii = 1:nScan
    cfgFcn = str2func(sprintf('config_batch_%s', batchName(ii)));
    cfg = cfgFcn();
    cfg = set_default_batch_options(cfg);

    rawPath = fullfile(cfg.paths.rawTxtRoot, rawName(ii) + ".txt");
    if ~isfile(rawPath)
        error('Selected raw TXT does not exist: %s', rawPath);
    end

    fprintf('[%02d/%02d] %s | %s\n', ...
        ii, nScan, batchName(ii), rawName(ii));
    [D, info] = read_pfm_txt_nanoscope_legacy(char(rawPath), cfg);
    if ~isfield(D, 'LS_PR_Phase') || ~isfield(D, 'LS_PR_Inphase')
        error('Missing phase or inphase channel in: %s', rawPath);
    end

    phase = double(D.LS_PR_Phase);
    inphase = double(D.LS_PR_Inphase);
    if ~isequal(size(phase), size(inphase))
        error('Phase/inphase size mismatch in: %s', rawPath);
    end

    phaseMaps{ii} = phase;
    inphaseMaps{ii} = inphase;
    infoList{ii} = info;
    individualDisplayAbsCLim_V(ii) = robust_abs_limit( ...
        inphase, inphaseAbsPercentile);

    finitePhase = phase(isfinite(phase));
    finiteInphase = inphase(isfinite(inphase));
    if ~isempty(finitePhase)
        phaseMin_deg(ii) = min(finitePhase);
        phaseMax_deg(ii) = max(finitePhase);
    end
    if ~isempty(finiteInphase)
        inphaseMin_V(ii) = min(finiteInphase);
        inphaseMax_V(ii) = max(finiteInphase);
        inphaseStd_V(ii) = std(finiteInphase);
    end

    pngName = sprintf('%s_%s_raw_phase_inphase.png', ...
        batchName(ii), rawName(ii));
    pngPath = fullfile(individualRoot, pngName);
    plot_individual_pair(phase, inphase, info, selection(ii, :), ...
        phaseCLim, individualDisplayAbsCLim_V(ii), pngPath, resolution);
    individualFigure(ii) = string(pngPath);
end

groupList = unique(groupID, 'stable');
overviewFigure = strings(numel(groupList), 1);
for gg = 1:numel(groupList)
    rows = find(groupID == groupList(gg));
    groupValues = collect_finite_abs(inphaseMaps(rows));
    groupLimit = percentile_from_sorted(groupValues, inphaseAbsPercentile);
    groupLimit = ensure_positive_limit(groupLimit, groupValues);
    groupDisplayAbsCLim_V(rows) = groupLimit;

    pngPath = fullfile(overviewRoot, ...
        sprintf('%s_raw_phase_inphase_overview.png', groupList(gg)));
    plot_group_overview(phaseMaps(rows), inphaseMaps(rows), infoList(rows), ...
        selection(rows, :), phaseCLim, groupLimit, pngPath, resolution);
    overviewFigure(gg) = string(pngPath);
end

manifest = [selection, table(phaseMin_deg, phaseMax_deg, ...
    inphaseMin_V, inphaseMax_V, inphaseStd_V, ...
    individualDisplayAbsCLim_V, groupDisplayAbsCLim_V, individualFigure)];
manifestPath = fullfile(outputRoot, 'selected_raw_heatmap_manifest.csv');
writetable(manifest, manifestPath);

fprintf('\nSelected raw-channel outputs written:\n');
fprintf('  Manifest: %s\n', manifestPath);
fprintf('  Individual figures: %s (%d PNGs)\n', individualRoot, nScan);
fprintf('  Group overviews: %s (%d PNGs)\n\n', ...
    overviewRoot, numel(groupList));

function plot_individual_pair(phase, inphase, info, selectionRow, ...
        phaseCLim, inphaseLimit, pngPath, resolution)
    fig = figure('Color', 'w', 'Visible', 'off', 'WindowStyle', 'normal');
    set(fig, 'Units', 'pixels', 'Position', [100, 100, 1500, 680]);
    cleanup = onCleanup(@() close_if_valid(fig));

    layout = tiledlayout(fig, 1, 2, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    axPhase = nexttile(layout);
    draw_phase_axis(axPhase, phase, info, phaseCLim, 'Raw LS_PR_Phase');
    axInphase = nexttile(layout);
    draw_inphase_axis(axInphase, inphase, info, inphaseLimit, ...
        'Raw LS_PR_Inphase');

    title(layout, sprintf('%s | %s | %s | %s | no signal processing', ...
        selectionRow.batchName, selectionRow.rawName, ...
        selectionRow.geometry, selectionRow.recipe), ...
        'Interpreter', 'none', 'FontWeight', 'bold');
    exportgraphics(fig, pngPath, 'Resolution', resolution);
end

function plot_group_overview(phaseMaps, inphaseMaps, infoList, selection, ...
        phaseCLim, inphaseLimit, pngPath, resolution)
    nScan = numel(phaseMaps);
    figHeight = max(700, 330 * nScan);
    fig = figure('Color', 'w', 'Visible', 'off', 'WindowStyle', 'normal');
    set(fig, 'Units', 'pixels', 'Position', [100, 50, 1500, figHeight]);
    cleanup = onCleanup(@() close_if_valid(fig));

    layout = tiledlayout(fig, nScan, 2, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    for ii = 1:nScan
        rowLabel = sprintf('%s | %s', ...
            selection.batchName(ii), selection.rawName(ii));
        axPhase = nexttile(layout);
        draw_phase_axis(axPhase, phaseMaps{ii}, infoList{ii}, phaseCLim, ...
            sprintf('%s | raw phase', rowLabel));
        axInphase = nexttile(layout);
        draw_inphase_axis(axInphase, inphaseMaps{ii}, infoList{ii}, ...
            inphaseLimit, sprintf('%s | raw inphase', rowLabel));
    end

    title(layout, sprintf('%s | %s | common inphase CLim +/-%.4g V', ...
        selection.geometry(1), selection.recipe(1), inphaseLimit), ...
        'Interpreter', 'none', 'FontWeight', 'bold');
    exportgraphics(fig, pngPath, 'Resolution', resolution);
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

function limit = robust_abs_limit(A, percentile)
    values = sort(abs(double(A(isfinite(A)))));
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

function close_if_valid(fig)
    if isgraphics(fig)
        close(fig);
    end
end
