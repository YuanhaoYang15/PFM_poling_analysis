%% Plot every exported AFM channel for every TXT scan in the active AFM batch
%
% Outputs are written below:
%   local/batches/<batch>/results/afm/raw_qc/
%
% This is a plot-only raw-channel pass. It does not level, smooth, normalize,
% or otherwise analyze the exported matrices.

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

afmCfg = get_active_afm_batch_config();
afmCfg = set_default_afm_options(afmCfg);

plot_raw_export_heatmaps(afmCfg);
