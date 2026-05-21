%% Re-analyze selected scans only from LS_PR_Inphase
%
% Create or edit the active batch selected-scan table first:
%   main_select_scans_for_rework

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
batchName = batchCfg.batchName;
centerMode = 'inphase_optimized';
selectedOnly = true;

run(fullfile(pwd, 'functions', 'run_inphase_batch_analysis.m'));
