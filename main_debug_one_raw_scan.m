%% Debug one raw PFM scan import
% Use this when the opened image looks blank/weird.
%
% It loads the first row in scans metadata and prints the detected matrix
% size, coordinate range, phase range, and selected source file.

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
meta = read_batch_metadata(batchCfg);

% Change these two lines if you want to debug a specific scan.
deviceID_to_debug = string(meta.scans.deviceID(1));
scanID_to_debug = double(meta.scans.scanID(1));

scanRow = meta.scans(meta.scans.deviceID == deviceID_to_debug & ...
                     double(meta.scans.scanID) == scanID_to_debug, :);
if isempty(scanRow)
    error('Requested debug scan not found.');
end
scanRow = scanRow(1,:);

deviceRow = meta.devices(meta.devices.deviceID == string(scanRow.deviceID), :);
designRow = get_design_row(meta, string(deviceRow.designID));

[cfgScan, scanCfg] = build_scan_cfg_from_batch(batchCfg, deviceRow, scanRow, designRow);
data = load_pfm_data(cfgScan, scanCfg);

fprintf('\nSource file:\n  %s\n', data.sourceFile);
fprintf('Phase size: %d x %d\n', size(data.phase,1), size(data.phase,2));
fprintf('X range: %.6g to %.6g um\n', min(data.X(:), [], 'omitnan'), max(data.X(:), [], 'omitnan'));
fprintf('Y range: %.6g to %.6g um\n', min(data.Y(:), [], 'omitnan'), max(data.Y(:), [], 'omitnan'));
fprintf('Phase range: %.6g to %.6g deg\n', min(data.phase(:), [], 'omitnan'), max(data.phase(:), [], 'omitnan'));

figure('Color', 'w', 'Position', [100, 100, 900, 700]);
imagesc(data.X(1,:), data.Y(:,1), data.phase);
axis image;
set(gca, 'YDir', 'normal');
colorbar;
caxis(cfgScan.plot.phaseCLim);
xlabel('x (\mum)');
ylabel('y (\mum)');
title(sprintf('Debug import | %s scan %d', string(scanRow.deviceID), double(scanRow.scanID)), ...
    'Interpreter', 'none');
