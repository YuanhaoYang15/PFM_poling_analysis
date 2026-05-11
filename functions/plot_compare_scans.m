function fig = plot_compare_scans(cfg, results)
%PLOT_COMPARE_SCANS Compare all scans from one device.

nScan = numel(results);
rList = results(1).radiusList;
lambdaDesign = design_period(rList, cfg);
wgMin = cfg.design.R0 - cfg.design.w/2;
wgMax = cfg.design.R0 + cfg.design.w/2;

fig = figure('Color', 'w', 'Position', [120, 120, 1450, 820]);
if ~cfg.plot.showFigures
    set(fig, 'Visible', 'off');
end

%% 1. Period before correction
subplot(2,2,1);
hold on; grid on; box on;
yl = auto_period_ylim(results, lambdaDesign, 'before');
shade_radius_region(wgMin, wgMax, yl, cfg);
for ii = 1:nScan
    plot(rList, results(ii).before.periodMean, 'o-', 'LineWidth', 1.2, 'MarkerSize', 3);
end
plot(rList, lambdaDesign, 'k--', 'LineWidth', 1.2);
xlabel('radius r (\mum)');
ylabel('\Lambda (\mum)');
title('Period before center correction');
ylim(yl); xlim([cfg.radius.rMin, cfg.radius.rMax]);
legend(make_scan_legend(results, true), 'Location', 'best', 'Interpreter', 'none');

%% 2. Period after correction
subplot(2,2,2);
hold on; grid on; box on;
yl = auto_period_ylim(results, lambdaDesign, 'after');
shade_radius_region(wgMin, wgMax, yl, cfg);
for ii = 1:nScan
    plot(rList, results(ii).after.periodMean, 'o-', 'LineWidth', 1.2, 'MarkerSize', 3);
end
plot(rList, lambdaDesign, 'k--', 'LineWidth', 1.2);
xlabel('radius r (\mum)');
ylabel('\Lambda (\mum)');
title('Period after center correction');
ylim(yl); xlim([cfg.radius.rMin, cfg.radius.rMax]);
legend(make_scan_legend(results, true), 'Location', 'best', 'Interpreter', 'none');

%% 3. Duty cycle after correction
subplot(2,2,3);
hold on; grid on; box on;
shade_radius_region(wgMin, wgMax, [0, 1], cfg);
for ii = 1:nScan
    plot(rList, results(ii).after.dutyMean, 'o-', 'LineWidth', 1.2, 'MarkerSize', 3);
end
xlabel('radius r (\mum)');
ylabel('duty cycle');
title('Duty cycle after center correction');
ylim([0, 1]); xlim([cfg.radius.rMin, cfg.radius.rMax]);
legend(make_scan_legend(results, false), 'Location', 'best', 'Interpreter', 'none');

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

function yl = auto_period_ylim(results, lambdaDesign, fieldName)
    vals = lambdaDesign(:);
    for ii = 1:numel(results)
        vals = [vals; results(ii).(fieldName).periodMean(:)]; %#ok<AGROW>
    end
    vals = vals(isfinite(vals));
    if isempty(vals)
        yl = [1, 5];
    else
        pad = 0.15;
        yl = [min(vals)-pad, max(vals)+pad];
    end
end

function leg = make_scan_legend(results, includeDesign)
    n = numel(results);
    leg = cell(1, n + includeDesign);
    for ii = 1:n
        label = sprintf('scan %d', results(ii).scanID);
        if ~isempty(results(ii).positionLabel)
            label = sprintf('%s: %s', label, results(ii).positionLabel);
        end
        leg{ii} = label;
    end
    if includeDesign
        leg{end} = 'design';
    end
end
