function write_selected_scan_table(batchCfg, selectedTable)
%WRITE_SELECTED_SCAN_TABLE Save batch-specific selected-scans table.

selectedFile = get_selected_scan_file(batchCfg);

if ~exist(fileparts(selectedFile), 'dir')
    mkdir(fileparts(selectedFile));
end

writetable(selectedTable, selectedFile);

fprintf('Saved selected scans:\n  %s\n', selectedFile);

end
