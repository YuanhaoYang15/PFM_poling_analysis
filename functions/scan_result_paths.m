function paths = scan_result_paths(cfg, scanLike)
%SCAN_RESULT_PATHS Return processed result paths for one scan.
scanID = scanLike.scanID;
paths = struct();
paths.mat = fullfile(cfg.paths.processedData, sprintf('%s_scan_%d_processed.mat', cfg.deviceName, scanID));
paths.csv = fullfile(cfg.paths.processedData, sprintf('%s_scan_%d_radius_summary.csv', cfg.deviceName, scanID));
end
