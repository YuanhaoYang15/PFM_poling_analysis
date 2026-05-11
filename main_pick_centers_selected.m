%% Re-pick initial centers for selected scans only
%
% First create selected list interactively:
%   main_select_scans_for_rework
%
% Then run:
%   main_pick_centers_selected

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
batchCfg = set_default_batch_options(batchCfg);

pick_batch_centers(batchCfg, true);
