%% Analyze the active PFM poling batch
% Incremental workflow:
%   main_generate_metadata_from_raw_folder   % optional
%   main_pick_initial_centers_for_batch
%   main_analyze_batch
%
% Default behavior:
%   - Existing processed scans are loaded and reused.
%   - Missing/new scans are analyzed.
%   - Batch/device summaries are regenerated from all available results.

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
batchCfg = set_default_batch_options(batchCfg);

run_batch_analysis(batchCfg, false);
