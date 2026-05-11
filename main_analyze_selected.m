%% Re-analyze only selected scans
% Create or edit:
%   local/selected_scans.csv
%
% Required columns:
%   deviceID,scanID
%
% Optional columns:
%   rawName,action,notes
%
% This script forces reprocessing of selected scans, then regenerates the
% full batch summary from all available processed results.

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
batchCfg = set_default_batch_options(batchCfg);

run_batch_analysis(batchCfg, true);
