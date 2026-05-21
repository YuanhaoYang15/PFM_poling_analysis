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

fig = figure('Color', 'w', 'Position', [80, 80, 1450, 820], ...
    'Visible', visibleState);

subplot(2,2,1);
imagesc(data.X(1,:), data.Y(:,1), data.inphase);
axis image;
set(gca, 'YDir', 'normal');
colorbar;
xlabel('x (\mum)');
ylabel('y (\mum)');
title('PFM inphase map with selected radii', 'Interpreter', 'none');
hold on;

thetaPlot = linspace(-pi, pi, 1000);
rStart = cfg.radius.rMin;
rEnd = cfg.radius.rMax;

hCenter = plot(center(1), center(2), 'rx', 'LineWidth', 1.5, 'MarkerSize', 8);
hRStart = plot(center(1) + rStart*cos(thetaPlot), center(2) + rStart*sin(thetaPlot), ...
    'w-', 'LineWidth', 1.2);
hREnd = plot(center(1) + rEnd*cos(thetaPlot), center(2) + rEnd*sin(thetaPlot), ...
    'm-', 'LineWidth', 1.2);

plot(center(1) + wgMin*cos(thetaPlot), center(2) + wgMin*sin(thetaPlot), ...
    '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 1.0);
plot(center(1) + wgMax*cos(thetaPlot), center(2) + wgMax*sin(thetaPlot), ...
    '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 1.0);

legend([hCenter, hRStart, hREnd], ...
    {'center', sprintf('r = %.3f \\mum', rStart), sprintf('r = %.3f \\mum', rEnd)}, ...
    'Location', 'northwest', 'Interpreter', 'tex');

text(0.70, 0.82, sprintf(['Waveguide region:\n', ...
    'R_0 = %.3f \\mum\nw = %.3f \\mum\n[%.3f, %.3f] \\mum'], ...
    cfg.design.R0, cfg.design.w, wgMin, wgMax), ...
    'Units', 'normalized', 'BackgroundColor', 'w', 'EdgeColor', 'none', ...
    'Interpreter', 'tex');

subplot(2,2,2);
hold on; grid on; box on;
if ~isempty(ana.arc(1).s)
    plot(ana.arc(1).s, ana.arc(1).inphase, '-', 'LineWidth', 1.2);
end
if ~isempty(ana.arc(end).s)
    plot(ana.arc(end).s, ana.arc(end).inphase, '-', 'LineWidth', 1.2);
end
xlabel('arc length s (\mum)');
ylabel('Inphase (V)');
title('PFM inphase along circular arcs at start/end radii', 'Interpreter', 'none');
legend({sprintf('r = %.3f \\mum', rStart), sprintf('r = %.3f \\mum', rEnd)}, ...
    'Location', 'best', 'Interpreter', 'tex');

subplot(2,2,3);
hold on; grid on; box on;
shade_radius_region(wgMin, wgMax, [0, 1], cfg);
errorbar(rList, ana.dutyMean, ana.dutyStd, 'o-', 'LineWidth', 1.2, ...
    'MarkerSize', 3, 'CapSize', 4);
xlabel('radius r (\mum)');
ylabel('low-inphase duty cycle');
ylim([0, 1]);
xlim([cfg.radius.rMin, cfg.radius.rMax]);
title('Low-inphase duty cycle vs radius, error bar = STD across periods', ...
    'Interpreter', 'none');

text(0.60, 0.13, sprintf('WG-region average:\n<Duty> = %.4f\nstd = %.4f', ...
    result.WG_duty_mean, result.WG_duty_std), ...
    'Units', 'normalized', 'BackgroundColor', 'w', 'EdgeColor', 'none', ...
    'Interpreter', 'none');

subplot(2,2,4);
hold on; grid on; box on;
yl = period_ylim_from_design_local(lambdaDesign, cfg);
hWG = shade_radius_region(wgMin, wgMax, yl, cfg);
hMeas = errorbar(rList, ana.periodMean, ana.periodStd, 'o-', 'LineWidth', 1.2, ...
    'MarkerSize', 3, 'CapSize', 4);
hDesign = plot(rList, lambdaDesign, 'k--', 'LineWidth', 1.2);

xlabel('radius r (\mum)');
ylabel('poling period \Lambda (\mum)');
xlim([cfg.radius.rMin, cfg.radius.rMax]);
ylim(yl);
title('Inphase-derived period vs radius, error bar = STD across periods', ...
    'Interpreter', 'none');
legend([hWG, hMeas, hDesign], {'WG region', 'measured', 'design'}, ...
    'Location', 'best', 'Interpreter', 'none');

text(0.61, 0.12, sprintf(['WG-region average:\n', ...
    '<Period> = %.4f um\nstd = %.4f um\n<Nperiods> = %.2f'], ...
    result.WG_period_mean, result.WG_period_std, result.WG_Nperiod_mean), ...
    'Units', 'normalized', 'BackgroundColor', 'w', 'EdgeColor', 'none', ...
    'Interpreter', 'none');

sgtitle(sprintf('%s | scan %d | %s | LOW INPHASE | fixed center [%.3f, %.3f] um', ...
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
