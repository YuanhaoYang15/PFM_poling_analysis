%% Plot every exported raw channel for every TXT scan in the active batch
% Outputs are written below:
%   local/batches/<batch>/results/raw_qc/
%
% This is a plot-only raw-channel pass. It does not wrap, smooth, normalize,
% center, or otherwise analyze the exported matrices.

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
batchCfg = set_default_batch_options(batchCfg);

plot_raw_export_heatmaps(batchCfg);
