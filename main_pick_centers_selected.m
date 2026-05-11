%% Re-pick initial centers for selected scans only
% Create or edit:
%   local/selected_scans.csv
%
% Required columns:
%   deviceID,scanID
%
% Optional columns:
%   rawName,action,notes
%
% This script always re-picks the selected scans and overwrites their rows
% in local/initial_centers_batch_<batch>.mat/.csv.

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
batchCfg = set_default_batch_options(batchCfg);

pick_batch_centers(batchCfg, true);
