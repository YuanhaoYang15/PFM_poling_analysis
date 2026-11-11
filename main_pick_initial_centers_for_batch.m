%% Pick approximate initial centers for all missing centers in the active batch
% Optional for the default inphase workflow; use after inspecting center QC.
% Default behavior:
%   - Existing centers in the active batch centers/ folder are skipped.
%   - Missing centers are picked interactively.
%
% To force re-picking a few scans, use:
%   main_pick_centers_selected

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
batchCfg = set_default_batch_options(batchCfg);

pick_batch_centers(batchCfg, false);
