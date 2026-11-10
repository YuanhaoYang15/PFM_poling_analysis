function fig = plot_inphase_summary_figure(cfg, result)
%PLOT_INPHASE_SUMMARY_FIGURE Create a 4-panel low-inphase summary.

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

fig = figure('Color', 'w', 'Visible', visibleState, 'WindowStyle', 'normal');
set(fig, 'Position', [80, 80, 1450, 820]);
layout = tiledlayout(fig, 2, 2, ...
    'TileSpacing', 'compact', 'Padding', 'compact');

%% 1. Inphase map
axMap = nexttile(layout, 1);
imagesc(axMap, data.X(1,:), data.Y(:,1), data.inphase);
axis(axMap, 'image');
set(axMap, 'YDir', 'normal');
colorbar(axMap);
xlabel(axMap, 'x (\mum)');
ylabel(axMap, 'y (\mum)');
title(axMap, {'PFM inphase map with selected radii', ...
    sprintf('WG r=[%.3f, %.3f] um | R0=%.3f um | w=%.3f um', ...
    wgMin, wgMax, cfg.design.R0, cfg.design.w)}, ...
    'Interpreter', 'none');
hold(axMap, 'on');

thetaPlot = linspace(-pi, pi, 1000);
rStart = cfg.radius.rMin;
rEnd = cfg.radius.rMax;

hCenter = plot(axMap, center(1), center(2), 'rx', ...
    'LineWidth', 1.5, 'MarkerSize', 8);
hRStart = plot(axMap, center(1) + rStart*cos(thetaPlot), ...
    center(2) + rStart*sin(thetaPlot), 'w-', 'LineWidth', 1.2);
hREnd = plot(axMap, center(1) + rEnd*cos(thetaPlot), ...
    center(2) + rEnd*sin(thetaPlot), 'm-', 'LineWidth', 1.2);

plot(axMap, center(1) + wgMin*cos(thetaPlot), ...
    center(2) + wgMin*sin(thetaPlot), '-', ...
    'Color', [0.8 0.8 0.8], 'LineWidth', 1.0);
plot(axMap, center(1) + wgMax*cos(thetaPlot), ...
    center(2) + wgMax*sin(thetaPlot), '-', ...
    'Color', [0.8 0.8 0.8], 'LineWidth', 1.0);

legend(axMap, [hCenter, hRStart, hREnd], ...
    {'center', sprintf('r = %.3f um', rStart), ...
    sprintf('r = %.3f um', rEnd)}, ...
    'Location', 'southoutside', 'Orientation', 'horizontal', ...
    'NumColumns', 3, 'Box', 'off', 'Interpreter', 'none');

%% 2. Inphase along start/end radii
axArc = nexttile(layout, 2);
hold(axArc, 'on');
grid(axArc, 'on');
box(axArc, 'on');
if ~isempty(ana.arc(1).s)
    plot(axArc, ana.arc(1).s, ana.arc(1).inphase, '-', 'LineWidth', 1.2);
end
if ~isempty(ana.arc(end).s)
    plot(axArc, ana.arc(end).s, ana.arc(end).inphase, '-', 'LineWidth', 1.2);
end
xlabel(axArc, 'arc length s (\mum)');
ylabel(axArc, 'Inphase (V)');
title(axArc, 'PFM inphase along circular arcs at start/end radii', ...
    'Interpreter', 'none');
legend(axArc, {sprintf('r = %.3f um', rStart), ...
    sprintf('r = %.3f um', rEnd)}, ...
    'Location', 'best', 'Interpreter', 'none');

%% 3. Duty cycle vs radius
axDuty = nexttile(layout, 3);
hold(axDuty, 'on');
grid(axDuty, 'on');
box(axDuty, 'on');
shade_radius_region(wgMin, wgMax, [0, 1], cfg);
errorbar(axDuty, rList, ana.dutyMean, ana.dutyStd, 'o-', ...
    'LineWidth', 1.2, 'MarkerSize', 3, 'CapSize', 4);
xlabel(axDuty, 'radius r (\mum)');
ylabel(axDuty, 'low-inphase duty cycle');
ylim(axDuty, [0, 1]);
xlim(axDuty, [cfg.radius.rMin, cfg.radius.rMax]);
title(axDuty, 'Low-inphase duty cycle vs radius, error bar = STD across periods', ...
    'Interpreter', 'none');
text(axDuty, 0.60, 0.13, ...
    sprintf('WG-region average:\n<Duty> = %.4f\nstd = %.4f', ...
    result.WG_duty_mean, result.WG_duty_std), ...
    'Units', 'normalized', 'BackgroundColor', 'w', 'EdgeColor', 'none', ...
    'Interpreter', 'none');

%% 4. Period vs radius
axPeriod = nexttile(layout, 4);
hold(axPeriod, 'on');
grid(axPeriod, 'on');
box(axPeriod, 'on');
yl = period_ylim_from_design_local(lambdaDesign, cfg);
hWG = shade_radius_region(wgMin, wgMax, yl, cfg);
hMeas = errorbar(axPeriod, rList, ana.periodMean, ana.periodStd, 'o-', ...
    'LineWidth', 1.2, 'MarkerSize', 3, 'CapSize', 4);
hDesign = plot(axPeriod, rList, lambdaDesign, 'k--', 'LineWidth', 1.2);
xlabel(axPeriod, 'radius r (\mum)');
ylabel(axPeriod, 'poling period \Lambda (\mum)');
xlim(axPeriod, [cfg.radius.rMin, cfg.radius.rMax]);
ylim(axPeriod, yl);
title(axPeriod, 'Inphase-derived period vs radius, error bar = STD across periods', ...
    'Interpreter', 'none');
legend(axPeriod, [hWG, hMeas, hDesign], ...
    {'WG region', 'measured', 'design'}, ...
    'Location', 'best', 'Interpreter', 'none');
text(axPeriod, 0.61, 0.12, sprintf(['WG-region average:\n', ...
    '<Period> = %.4f um\nstd = %.4f um\n<Nperiods> = %.2f'], ...
    result.WG_period_mean, result.WG_period_std, result.WG_Nperiod_mean), ...
    'Units', 'normalized', 'BackgroundColor', 'w', 'EdgeColor', 'none', ...
    'Interpreter', 'none');

title(layout, sprintf( ...
    '%s | scan %d | %s | LOW INPHASE | fixed center [%.3f, %.3f] um', ...
    result.deviceName, result.scanID, result.rawName, center(1), center(2)), ...
    'FontWeight', 'bold', 'Interpreter', 'none');

end

function yl = period_ylim_from_design_local(lambdaDesign, cfg)
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
