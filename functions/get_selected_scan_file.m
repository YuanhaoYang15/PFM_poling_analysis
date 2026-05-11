function selectedFile = get_selected_scan_file(batchCfg)
%GET_SELECTED_SCAN_FILE Return batch-specific selected-scans CSV path.

localDir = fullfile(batchCfg.paths.projectRoot, 'local');
if ~exist(localDir, 'dir')
    mkdir(localDir);
end

selectedFile = fullfile(localDir, ...
    sprintf('selected_scans_batch_%s.csv', batchCfg.batchName));

end
