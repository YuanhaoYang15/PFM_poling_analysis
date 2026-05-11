%% Clear selected-scans table for the active batch

clear; clc;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
batchCfg = set_default_batch_options(batchCfg);

selectedFile = get_selected_scan_file(batchCfg);

if isfile(selectedFile)
    delete(selectedFile);
    fprintf('Deleted selected-scans file:\n  %s\n', selectedFile);
else
    fprintf('No selected-scans file found:\n  %s\n', selectedFile);
end
