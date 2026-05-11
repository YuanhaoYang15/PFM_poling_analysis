%% Analyze one circularly poled device with multiple PFM scans
% Edit config/config_E7_R1C2.m before running.

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

cfg = config_E7_R1C2();

if ~exist(cfg.paths.processedData, 'dir'); mkdir(cfg.paths.processedData); end
if ~exist(cfg.paths.figures, 'dir'); mkdir(cfg.paths.figures); end

nScan = numel(cfg.scans);
results = repmat(struct(), 1, nScan);

fprintf('\n========================================\n');
fprintf('Device: %s\n', cfg.deviceName);
fprintf('Number of scans: %d\n', nScan);
fprintf('Raw txt root: %s\n', cfg.paths.rawTxtRoot);
fprintf('========================================\n\n');

for ii = 1:nScan
    rawLabel = getfield_or(cfg.scans(ii), 'rawName', getfield_or(cfg.scans(ii), 'fileName', ''));
    fprintf('--- Scan %d/%d: %s ---\n', ii, nScan, rawLabel);

    results(ii) = analyze_one_pfm_scan(cfg, cfg.scans(ii));

    save_processed_results(cfg, results(ii));

    fig = plot_summary_figure(cfg, results(ii));
    figName = sprintf('Summary_%s_scan_%d.png', cfg.deviceName, results(ii).scanID);
    exportgraphics(fig, fullfile(cfg.paths.figures, figName), 'Resolution', cfg.plot.resolution);
    savefig(fig, fullfile(cfg.paths.figures, strrep(figName, '.png', '.fig')));

    fprintf('Finished scan %d.\n\n', results(ii).scanID);
end

summary = make_device_summary(cfg, results);
save(fullfile(cfg.paths.processedData, sprintf('%s_all_scans_summary.mat', cfg.deviceName)), ...
    'cfg', 'results', 'summary');

if nScan >= 2
    figCompare = plot_compare_scans(cfg, results);
    figName = sprintf('Compare_%s_all_scans.png', cfg.deviceName);
    exportgraphics(figCompare, fullfile(cfg.paths.figures, figName), 'Resolution', cfg.plot.resolution);
    savefig(figCompare, fullfile(cfg.paths.figures, strrep(figName, '.png', '.fig')));
end

fprintf('All scans finished.\n');
fprintf('Figures saved to: %s\n', cfg.paths.figures);
fprintf('Processed data saved to: %s\n', cfg.paths.processedData);
