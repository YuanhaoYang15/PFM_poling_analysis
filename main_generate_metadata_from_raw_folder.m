%% Generate or update batch metadata from raw txt file names
% This script scans the active batch raw folder and updates:
%   local/batches/<batch>/metadata/scans.csv
%   local/batches/<batch>/metadata/devices.csv
%   local/batches/<batch>/metadata/designs.csv
%
% Existing rows are preserved; new raw files/devices/designs are appended.

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
batchCfg = set_default_batch_options(batchCfg);

generate_metadata_from_raw_folder(batchCfg);
