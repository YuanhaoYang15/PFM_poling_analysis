function paths = local_paths_template()
%LOCAL_PATHS_TEMPLATE Template for machine-specific local paths.
%
% Usage:
%   1. Copy this file to:
%        local_paths.m
%   2. Edit the paths below for your own computer.
%   3. local_paths.m is ignored by Git and should not be committed.
%
% This lets the code project stay clean while raw data can live anywhere.

paths = struct();

% Raw data roots for different PFM/poling test batches.
% These are examples based on your current folder organization.
paths.rawRoots = struct();

paths.rawRoots.batch_20260511 = ...
    'D:\Project\NUS\Project\Single Photon Nonlinearity\Image\20260511';

paths.rawRoots.batch_20260506 = ...
    'D:\Project\NUS\Project\Single Photon Nonlinearity\Image\20260506';

% Optional: external output root.
% Leave empty to save processed_data/ and figures/ inside the code project.
% Example:
% paths.outputRoot = 'D:\Project\NUS\Project\Single Photon Nonlinearity\PFM_analysis_outputs';
paths.outputRoot = '';

end
