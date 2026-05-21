function selectedFile = get_selected_scan_file(batchCfg)
%GET_SELECTED_SCAN_FILE Return batch-specific selected-scans CSV path.

selectionRoot = batchCfg.paths.selectionRoot;
if ~exist(selectionRoot, 'dir')
    mkdir(selectionRoot);
end

selectedFile = fullfile(selectionRoot, 'selected_scans.csv');

end
