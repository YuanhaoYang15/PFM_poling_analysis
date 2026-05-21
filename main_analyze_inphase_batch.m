%% Analyze the active PFM poling batch from LS_PR_Inphase
%
% This uses picked initial centers and refines them by inphase period unless
% centerMode is changed before running the inphase batch runner.

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
batchName = batchCfg.batchName;
centerMode = 'inphase_optimized';

run(fullfile(pwd, 'functions', 'run_inphase_batch_analysis.m'));
