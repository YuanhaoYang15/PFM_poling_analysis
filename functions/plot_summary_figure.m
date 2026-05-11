function fig = plot_summary_figure(cfg, result)
%PLOT_SUMMARY_FIGURE Create 4-panel summary figure for one scan.

cfg = set_default_batch_options(cfg);

data = result.data;
ana = result.after;
rList = result.radiusList;
center = result.centerOptimized;

lambdaDesign = design_period(rList, cfg);

wgMin = cfg.design.R0 - cfg.design.w/2;
wgMax = cfg.design.R0 + cfg.design.w/2;

visibleState = 'on';
if ~cfg.plot.showFigures
    visibleState = 'off';
end

fig = figure('Color', 'w', 'Position', [80, 80, 1450, 820], ...
    'Visible', visibleState);

%% 1. Phase map
subplot(2,2,1);
imagesc(data.X(1,:), data.Y(:,1), data.phase);
axis image;
set(gca, 'YDir', 'normal');
colorbar;
caxis(cfg.plot.phaseCLim);
xlabel('x (\mum)');
ylabel('y (\mum)');
title('PFM phase map with selected radii', 'Interpreter', cfg.plot.interpreter);
hold on;

hCenter = plot(center(1), center(2), 'rx', 'LineWidth', 1.5, 'MarkerSize', 8);

thetaPlot = linspace(-pi, pi, 1000);
rStart = cfg.radius.rMin;
rEnd = cfg.radius.rMax;

hRStart = plot(center(1) + rStart*cos(thetaPlot), center(2) + rStart*sin(thetaPlot), ...
    'w-', 'LineWidth', 1.2);
hREnd = plot(center(1) + rEnd*cos(thetaPlot), center(2) + rEnd*sin(thetaPlot), ...
    'm-', 'LineWidth', 1.2);

% Waveguide boundary arcs
plot(center(1) + wgMin*cos(thetaPlot), center(2) + wgMin*sin(thetaPlot), ...
    '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 1.0);
plot(center(1) + wgMax*cos(thetaPlot), center(2) + wgMax*sin(thetaPlot), ...
    '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 1.0);

text(0.70, 0.82, sprintf(['Waveguide region:\n', ...
    'R_0 = %.3f \\mum\nw = %.3f \\mum\n[%.3f, %.3f] \\mum'], ...
    cfg.design.R0, cfg.design.w, wgMin, wgMax), ...
    'Units', 'normalized', 'BackgroundColor', 'w', 'EdgeColor', 'none', ...
    'Interpreter', 'tex');

legend([hCenter, hRStart, hREnd], ...
    {'center', sprintf('r = %.3f \\mum', rStart), sprintf('r = %.3f \\mum', rEnd)}, ...
    'Location', 'northwest', 'Interpreter', 'tex');

%% 2. Phase along start/end radii
subplot(2,2,2);
hold on; grid on; box on;

idxStart = 1;
idxEnd = numel(ana.arc);

if ~isempty(ana.arc(idxStart).s)
    plot(ana.arc(idxStart).s, ana.arc(idxStart).phase, '-', 'LineWidth', 1.2);
end

if ~isempty(ana.arc(idxEnd).s)
    plot(ana.arc(idxEnd).s, ana.arc(idxEnd).phase, '-', 'LineWidth', 1.2);
end

xlabel('arc length s (\mum)');
ylabel('Phase (deg), wrapped to [-180, 180]');
title('PFM phase along circular arcs at start/end radii', ...
    'Interpreter', cfg.plot.interpreter);
legend({sprintf('r = %.3f \\mum', rStart), sprintf('r = %.3f \\mum', rEnd)}, ...
    'Location', 'best', 'Interpreter', 'tex');

%% 3. Duty cycle vs radius
subplot(2,2,3);
hold on; grid on; box on;

shade_radius_region(wgMin, wgMax, [0, 1], cfg);
errorbar(rList, ana.dutyMean, ana.dutyStd, 'o-', 'LineWidth', 1.2, ...
    'MarkerSize', 3, 'CapSize', 4);

xlabel('radius r (\mum)');
ylabel('duty cycle');
ylim([0, 1]);
xlim([cfg.radius.rMin, cfg.radius.rMax]);
title('Poling duty cycle vs radius, error bar = STD across periods', ...
    'Interpreter', cfg.plot.interpreter);

txt = sprintf('WG-region average:\n<Duty> = %.4f\nstd = %.4f', ...
    result.WG_duty_mean, result.WG_duty_std);
text(0.60, 0.13, txt, 'Units', 'normalized', ...
    'BackgroundColor', 'w', 'EdgeColor', 'none', 'Interpreter', 'none');

%% 4. Poling period vs radius
subplot(2,2,4);
hold on; grid on; box on;

yl = period_ylim_from_design(lambdaDesign, cfg);
hWG = shade_radius_region(wgMin, wgMax, yl, cfg);

hMeas = errorbar(rList, ana.periodMean, ana.periodStd, 'o-', 'LineWidth', 1.2, ...
    'MarkerSize', 3, 'CapSize', 4);
hDesign = plot(rList, lambdaDesign, 'k--', 'LineWidth', 1.2);

xlabel('radius r (\mum)');
ylabel('poling period \Lambda (\mum)');
xlim([cfg.radius.rMin, cfg.radius.rMax]);
ylim(yl);
title('Poling period vs radius, error bar = STD across periods', ...
    'Interpreter', cfg.plot.interpreter);

legend([hWG, hMeas, hDesign], {'WG region', 'measured', 'design'}, ...
    'Location', 'best', 'Interpreter', 'none');

txt = sprintf(['WG-region average:\n', ...
    '<Period> = %.4f um\nstd = %.4f um\n<Nperiods> = %.2f'], ...
    result.WG_period_mean, result.WG_period_std, result.WG_Nperiod_mean);
text(0.61, 0.12, txt, 'Units', 'normalized', ...
    'BackgroundColor', 'w', 'EdgeColor', 'none', 'Interpreter', 'none');

rawLabel = get_result_label(result);
sgtitle(sprintf('%s | scan %d | %s | center shift = [%.3f, %.3f] um', ...
    result.deviceName, result.scanID, rawLabel, ...
    result.centerShift(1), result.centerShift(2)), ...
    'FontWeight', 'bold', 'Interpreter', 'none');

end

function yl = period_ylim_from_design(lambdaDesign, cfg)
    switch lower(cfg.plot.periodYLimMode)
        case {'design_pm', 'design_pm_range'}
            halfRange = cfg.plot.periodYLimHalfRange;
            yl = [min(lambdaDesign, [], 'omitnan') - halfRange, ...
                  max(lambdaDesign, [], 'omitnan') + halfRange];
        case {'data'}
            yl = [cfg.extract.minPeriodUm, cfg.extract.maxPeriodUm];
        otherwise
            halfRange = cfg.plot.periodYLimHalfRange;
            yl = [min(lambdaDesign, [], 'omitnan') - halfRange, ...
                  max(lambdaDesign, [], 'omitnan') + halfRange];
    end

    if any(~isfinite(yl)) || diff(yl) <= 0
        yl = [cfg.extract.minPeriodUm, cfg.extract.maxPeriodUm];
    end
end

function rawLabel = get_result_label(result)
    if isfield(result, 'rawFileName') && ~isempty(result.rawFileName)
        rawLabel = result.rawFileName;
    elseif isfield(result, 'rawName') && ~isempty(result.rawName)
        rawLabel = result.rawName;
    else
        rawLabel = '';
    end
end
