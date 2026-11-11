function figs = plot_center_qc_sheet(batchCfg, results)
%PLOT_CENTER_QC_SHEET Unwrap inphase stripes about each saved final center.

batchCfg = set_default_batch_options(batchCfg);
nPages = ceil(numel(results)/12);
figs = gobjects(1, nPages);
try
    for ipage = 1:nPages
        visibleState = 'off';
        if batchCfg.plot.showFigures; visibleState = 'on'; end
        figs(ipage) = figure('Color', 'w', 'Visible', visibleState, ...
            'WindowStyle', 'normal', 'Position', [60, 60, 2000, 1350]);
        layout = tiledlayout(figs(ipage), 3, 4, ...
            'TileSpacing', 'compact', 'Padding', 'compact');
        first = (ipage-1)*12 + 1;
        last = min(ipage*12, numel(results));
        for k = first:last
            ax = nexttile(layout);
            plot_scan_local(ax, batchCfg, results(k));
        end
        title(layout, sprintf(['Center QC | %s | page %d/%d\n', ...
            'White: waveguide | magenta: analysis range | dotted: fitted low-inphase stripe centers'], ...
            char(string(batchCfg.batchName)), ipage, nPages), ...
            'Interpreter', 'none', 'FontSize', 12);
    end
catch exception
    close(figs(isgraphics(figs)));
    rethrow(exception);
end
end

function plot_scan_local(ax, batchCfg, result)
cfg = batchCfg;
if isfield(result, 'configUsed') && ~isempty(result.configUsed)
    cfg = result.configUsed;
end
cfg = set_default_batch_options(cfg);
data = result.data;
center = result.centerOptimized;
R0 = cfg.design.R0;
N = 2*pi*cfg.design.periodRef.Rref/cfg.design.periodRef.LambdaRef;
rRange = cfg.centerOpt.coherence.radiusRange;
if isempty(rRange); rRange = [cfg.radius.rMin, cfg.radius.rMax]; end
[~, objective] = center_stripe_coherence(center, data.X, data.Y, ...
    data.inphase, N, sort(rRange(:).'), cfg.centerOpt.coherence.taper_um, ...
    cfg.centerOpt.coherence.minPixels);
thetaRef = objective.thetaRef;
if ~isfinite(thetaRef)
    thetaRef = atan2(mean(data.Y(:), 'omitnan')-center(2), ...
        mean(data.X(:), 'omitnan')-center(1));
end

rLimits = [cfg.radius.rMin-3, cfg.radius.rMax+3];
radius = hypot(data.X-center(1), data.Y-center(2));
finitePixel = isfinite(data.X) & isfinite(data.Y) & isfinite(data.inphase);
visiblePixel = finitePixel & radius >= rLimits(1) & radius <= rLimits(2);
if ~any(visiblePixel(:)); visiblePixel = finitePixel; end
thetaRelative = angle(complex(data.X-center(1), data.Y-center(2))*exp(-1i*thetaRef));
thetaLimits = [min(thetaRelative(visiblePixel)), max(thetaRelative(visiblePixel))];
if isempty(thetaLimits) || any(~isfinite(thetaLimits)) || diff(thetaLimits) <= 0
    thetaLimits = [-pi, pi];
end
thetaMiddle = mean(thetaLimits);
pixelSteps = [abs(diff(data.X(1,:))), abs(diff(data.Y(:,1))).'];
pixelSteps = pixelSteps(isfinite(pixelSteps) & pixelSteps > 0);
pixelStep = 0.05;
if ~isempty(pixelSteps); pixelStep = min(pixelSteps); end
nTheta = min(1600, max(512, ceil(diff(thetaLimits)*max(abs(rLimits))/pixelStep)+1));
nRadius = min(1000, max(200, ceil(diff(rLimits)/pixelStep)+1));
theta = linspace(thetaLimits(1), thetaLimits(2), nTheta);
r = linspace(rLimits(1), rLimits(2), nRadius).';
xq = center(1) + r*cos(theta+thetaRef);
yq = center(2) + r*sin(theta+thetaRef);
image = interp2(data.X(1,:), data.Y(:,1), double(data.inphase), xq, yq, 'linear', NaN);
s = R0*(theta-thetaMiddle);
h = imagesc(ax, s, r, image);
set(h, 'AlphaData', isfinite(image));
set(ax, 'YDir', 'normal', 'Color', [0.85, 0.85, 0.85], 'FontSize', 8);
colormap(ax, gray(256));
finiteValues = sort(image(isfinite(image)));
if numel(finiteValues) >= 50
    % Percentile limits: a few bright debris pixels must not flatten the stripes.
    limits = finiteValues(round([0.02, 0.98]*(numel(finiteValues) - 1)) + 1);
    if limits(2) > limits(1)
        clim(ax, limits(:).');
    end
end
hold(ax, 'on');
wg = cfg.design.R0 + [-1, 1]*cfg.design.w/2;
analysisLimits = [cfg.radius.rMin, cfg.radius.rMax];
for k = 1:2
    yline(ax, wg(k), 'w-', 'LineWidth', 1.1);
    yline(ax, analysisLimits(k), 'm--', 'LineWidth', 1.0);
end
if isfinite(objective.phase)
    % The negative Fourier sign places low-inphase minima at phase pi.
    firstK = ceil((N*thetaLimits(1)+objective.phase-pi)/(2*pi));
    lastK = floor((N*thetaLimits(2)+objective.phase-pi)/(2*pi));
    stripeTheta = (pi-objective.phase+2*pi*(firstK:lastK))/N;
    stripeS = R0*(stripeTheta-thetaMiddle);
    for k = 1:numel(stripeS)
        xline(ax, stripeS(k), ':', 'Color', [1, 0.8, 0], 'LineWidth', 0.7);
    end
end
xlim(ax, s([1, end]));
ylim(ax, rLimits);
xlabel(ax, 'arc length at R0 from visible middle (\mum)');
ylabel(ax, 'radius (\mum)');

source = text_field_local(result, 'centerSource');
method = text_field_local(result, 'centerMethod');
qc = struct('flag', false, 'reasons', strings(0,1), ...
    'finalCoherence', NaN, 'peakRatio', NaN, 'finalPeriodError_um', NaN);
if isfield(result, 'centerQC') && ~isempty(result.centerQC)
    fields = fieldnames(qc);
    for k = 1:numel(fields)
        if isfield(result.centerQC, fields{k})
            qc.(fields{k}) = result.centerQC.(fields{k});
        end
    end
end
lines = {char(string(result.rawName)), sprintf('%s | %s', source, method), ...
    sprintf('coherence %.3f | peak %.3f | period err %+.4f um', ...
        qc.finalCoherence, qc.peakRatio, qc.finalPeriodError_um)};
titleColor = [0, 0, 0];
if qc.flag
    titleColor = [0.8, 0, 0];
    reasons = strjoin(string(qc.reasons(:).'), '; ');
    wrapped = regexp(char(reasons), '.{1,68}(\s|$)|\S{1,68}', 'match');
    lines = [lines, wrapped];
end
title(ax, lines, 'Interpreter', 'none', 'FontSize', 8, ...
    'Color', titleColor, 'FontWeight', 'bold');
end

function value = text_field_local(result, field)
value = '';
if isfield(result, field) && ~isempty(result.(field))
    value = char(string(result.(field)));
end
end
