function save_processed_results(cfg, result)
%SAVE_PROCESSED_RESULTS Save processed result for one scan.
if ~exist(cfg.paths.processedData, 'dir')
    mkdir(cfg.paths.processedData);
end

paths = scan_result_paths(cfg, result);
result.savedOn = datestr(now);
save(paths.mat, 'result', '-v7.3');

T = table();
T.radius_um = result.radiusList(:);
T.period_before_um = result.before.periodMean(:);
T.period_after_um = result.after.periodMean(:);
T.period_std_after_um = result.after.periodStd(:);
T.duty_after = result.after.dutyMean(:);
T.duty_std_after = result.after.dutyStd(:);
T.nPeriods_after = result.after.nPeriods(:);
writetable(T, paths.csv);
end
