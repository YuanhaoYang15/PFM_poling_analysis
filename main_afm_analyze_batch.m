%% Analyze the active AFM batch
%
% Levels height images, extracts cross-ridge profiles, and measures ridge
% top to left/right floor step heights (etch depth).
%
% Outputs under local/batches/<batch>/results/afm/:
%   processed_data/<rawName>_processed.mat
%   processed_data/afm_summary_<batchName>.csv
%   figures/<rawName>_summary.png
%   progress.log

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

afmCfg = get_active_afm_batch_config();
run_afm_batch_analysis(afmCfg);
