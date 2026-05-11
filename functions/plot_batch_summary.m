function fig = plot_batch_summary(batchCfg, batchSummary)
%PLOT_BATCH_SUMMARY Plot compact batch-level summary.

fig = figure('Color', 'w', 'Position', [120, 120, 1450, 820]);
if ~batchCfg.plot.showFigures
    set(fig, 'Visible', 'off');
end

n = height(batchSummary);
x = 1:n;

labels = strings(n,1);
for ii = 1:n
    labels(ii) = sprintf('%s-%d', batchSummary.deviceID(ii), batchSummary.scanID(ii));
end

subplot(2,2,1);
hold on; grid on; box on;
scatter(x, batchSummary.WG_period_mean_um, 40, 'filled');
yline(0, ':');
xlabel('scan index');
ylabel('<\Lambda> in WG region (\mum)');
title('WG-region mean period');
xlim([0, n+1]);

subplot(2,2,2);
hold on; grid on; box on;
scatter(x, batchSummary.WG_period_error_um, 40, 'filled');
yline(0, 'k--');
xlabel('scan index');
ylabel('period error (\mum)');
title('Period error relative to design at R_0');
xlim([0, n+1]);

subplot(2,2,3);
hold on; grid on; box on;
scatter(x, batchSummary.WG_duty_mean, 40, 'filled');
yline(0.5, 'k--');
xlabel('scan index');
ylabel('<Duty> in WG region');
ylim([0, 1]);
title('WG-region mean duty cycle');
xlim([0, n+1]);

subplot(2,2,4);
hold on; grid on; box on;
scatter(x, batchSummary.centerShiftAbs_um, 40, 'filled');
xlabel('scan index');
ylabel('|center shift| (\mum)');
title('Center correction magnitude');
xlim([0, n+1]);

sgtitle(sprintf('Batch summary | %s', batchCfg.batchName), ...
    'FontWeight', 'bold', 'Interpreter', 'none');

% Add a compact table-like annotation for scan index mapping.
annotationText = strings(min(n, 20), 1);
for ii = 1:min(n, 20)
    annotationText(ii) = sprintf('%d: %s', ii, labels(ii));
end
annotation('textbox', [0.78, 0.02, 0.21, 0.25], ...
    'String', strjoin(annotationText, newline), ...
    'Interpreter', 'none', 'FitBoxToText', 'off', ...
    'BackgroundColor', 'w', 'EdgeColor', [0.7 0.7 0.7]);

end
