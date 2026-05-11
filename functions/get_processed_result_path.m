function matPath = get_processed_result_path(cfgScan, scanID)
%GET_PROCESSED_RESULT_PATH Return processed MAT path for one scan.

matPath = fullfile(cfgScan.paths.processedData, ...
    sprintf('%s_scan_%d_processed.mat', cfgScan.deviceName, double(scanID)));

end
