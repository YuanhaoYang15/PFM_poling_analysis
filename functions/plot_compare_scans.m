function fig = plot_compare_scans(cfg, results)
%PLOT_COMPARE_SCANS Compare all scans from one device.

cfg = set_default_batch_options(cfg);

nScan = numel(results);
rList = results(1).radiusList;
lambdaDesign = design_period(rList, cfg);

wgMin = cfg.design.R0 - cfg.design.w/2;
wgMax = cfg.design.R0 + cfg.design.w/2;

visibleState = 'on';
if ~cfg.plot.showFigures
    visibleState = 'off';
end

fig = figure('Color', 'w', 'Position', [120, 120, 1450, 820], ...
    'Visible', visibleState);

%% 1. Period before correction
subplot(2,2,1);
hold on; grid on; box on;

yl = period_ylim_from_design(lambdaDesign, cfg);
hWG = shade_radius_region(wgMin, wgMax, yl, cfg);

hScan = gobjects(1, nScan);
for ii = 1:nScan
    hScan(ii) = plot(rList, results(ii).before.periodMean, 'o-', ...
        'LineWidth', 1.2, 'MarkerSize', 3);
end
hDesign = plot(rList, lambdaDesign, 'k--', 'LineWidth', 1.2);

xlabel('radius r (\mum)');
ylabel('\Lambda (\mum)');
title('Period before center correction');
ylim(yl);
xlim([cfg.radius.rMin, cfg.radius.rMax]);
legend([hScan, hDesign, hWG], [make_scan_legend(results), {'design', 'WG region'}], ...
    'Location', 'best', 'Interpreter', 'none');

%% 2. Period after correction
subplot(2,2,2);
hold on; grid on; box on;

yl = period_ylim_from_design(lambdaDesign, cfg);
hWG = shade_radius_region(wgMin, wgMax, yl, cfg);

hScan = gobjects(1, nScan);
for ii = 1:nScan
    hScan(ii) = plot(rList, results(ii).after.periodMean, 'o-', ...
        'LineWidth', 1.2, 'MarkerSize', 3);
end
hDesign = plot(rList, lambdaDesign, 'k--', 'LineWidth', 1.2);

xlabel('radius r (\mum)');
ylabel('\Lambda (\mum)');
title('Period after center correction');
ylim(yl);
xlim([cfg.radius.rMin, cfg.radius.rMax]);
legend([hScan, hDesign, hWG], [make_scan_legend(results), {'design', 'WG region'}], ...
    'Location', 'best', 'Interpreter', 'none');

%% 3. Duty cycle after correction
subplot(2,2,3);
hold on; grid on; box on;

hWG = shade_radius_region(wgMin, wgMax, [0, 1], cfg);
hScan = gobjects(1, nScan);
for ii = 1:nScan
    hScan(ii) = plot(rList, results(ii).after.dutyMean, 'o-', ...
        'LineWidth', 1.2, 'MarkerSize', 3);
end

xlabel('radius r (\mum)');
ylabel('duty cycle');
title('Duty cycle after center correction');
ylim([0, 1]);
xlim([cfg.radius.rMin, cfg.radius.rMax]);
legend([hScan, hWG], [make_scan_legend(results), {'WG region'}], ...
    'Location', 'best', 'Interpreter', 'none');

%% 4. WG-region averaged values
subplot(2,2,4);
hold on; grid on; box on;

scanIDs = [results.scanID];
periodMean = [results.WG_period_mean];
periodStd = [results.WG_period_std];
dutyMean = [results.WG_duty_mean];
dutyStd = [results.WG_duty_std];

yyaxis left;
errorbar(scanIDs, periodMean, periodStd, 'o-', 'LineWidth', 1.2, 'MarkerSize', 5);
ylabel('<\Lambda> in WG region (\mum)');
yl = period_ylim_from_design(lambdaDesign, cfg);
ylim(yl);

yyaxis right;
errorbar(scanIDs, dutyMean, dutyStd, 's-', 'LineWidth', 1.2, 'MarkerSize', 5);
ylabel('<Duty> in WG region');
ylim([0, 1]);

xlabel('scan ID');
title('WG-region averaged period and duty cycle');
xticks(scanIDs);

sgtitle(sprintf('%s | all scans comparison', cfg.deviceName), ...
    'FontWeight', 'bold', 'Interpreter', 'none');

end

function yl = period_ylim_from_design(lambdaDesign, cfg)
    switch lower(cfg.plot.periodYLimMode)
        case {'design_pm', 'design_pm_range'}
            halfRange = cfg.plot.periodYLimHalfRange;
            yl = [min(lambdaDesign, [], 'omitnan') - halfRange, ...
                  max(lambdaDesign, [], 'omitnan') + halfRange];
        otherwise
            vals = lambdaDesign(:);
            vals = vals(isfinite(vals));
            if isempty(vals)
                yl = [1, 5];
            else
                yl = [min(vals)-0.15, max(vals)+0.15];
            end
    end

    if any(~isfinite(yl)) || diff(yl) <= 0
        yl = [1, 5];
    end
end

function leg = make_scan_legend(results)
    n = numel(results);
    leg = cell(1, n);
    for ii = 1:n
        label = sprintf('scan %d', results(ii).scanID);
        if isfield(results(ii), 'positionLabel') && ~isempty(results(ii).positionLabel)
            label = sprintf('%s: %s', label, results(ii).positionLabel);
        end
        leg{ii} = label;
    end
end
