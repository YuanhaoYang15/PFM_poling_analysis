function save_processed_results(cfg, result)
%SAVE_PROCESSED_RESULTS Save processed result for one scan.

if ~exist(cfg.paths.processedData, 'dir')
    mkdir(cfg.paths.processedData);
end

fileName = sprintf('%s_scan_%d_processed.mat', result.deviceName, result.scanID);
save(fullfile(cfg.paths.processedData, fileName), 'result', '-v7.3');

% Also save a compact table for quick inspection.
T = table();
T.radius_um = result.radiusList(:);
T.period_before_um = result.before.periodMean(:);
T.period_after_um = result.after.periodMean(:);
T.period_std_after_um = result.after.periodStd(:);
T.duty_after = result.after.dutyMean(:);
T.duty_std_after = result.after.dutyStd(:);
T.nPeriods_after = result.after.nPeriods(:);

csvName = sprintf('%s_scan_%d_radius_summary.csv', result.deviceName, result.scanID);
writetable(T, fullfile(cfg.paths.processedData, csvName));

end
