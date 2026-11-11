%% Analyze the active PFM poling batch from LS_PR_Inphase
%
% Default: find centers by stripe coherence; picked centers are optional.
% Review the batch center QC sheet and flagged scans after analysis.

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
batchName = batchCfg.batchName;
centerMode = 'inphase_optimized';

run(fullfile(pwd, 'functions', 'run_inphase_batch_analysis.m'));
