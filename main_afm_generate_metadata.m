%% Generate AFM scan metadata for the active AFM batch
%
% Scans the batch raw folder and merges metadata/afm_scans.csv. Existing
% rows and manual edits are preserved.

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

afmCfg = get_active_afm_batch_config();
generate_afm_metadata(afmCfg);
