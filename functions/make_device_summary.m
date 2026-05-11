function summary = make_device_summary(cfg, results)
%MAKE_DEVICE_SUMMARY Create compact all-scan summary.

n = numel(results);

summary = struct();
summary.deviceName = cfg.deviceName;
summary.nScan = n;
summary.scanIDs = nan(1, n);
summary.rawFileNames = strings(1, n);
summary.positionLabels = strings(1, n);

summary.centerInitial_all = nan(n, 2);
summary.centerOptimized_all = nan(n, 2);
summary.centerShift_all = nan(n, 2);

summary.WG_period_mean_all = nan(1, n);
summary.WG_period_std_all = nan(1, n);
summary.WG_duty_mean_all = nan(1, n);
summary.WG_duty_std_all = nan(1, n);
summary.WG_Nperiod_mean_all = nan(1, n);

for ii = 1:n
    summary.scanIDs(ii) = results(ii).scanID;
    summary.rawFileNames(ii) = string(results(ii).rawFileName);
    summary.positionLabels(ii) = string(results(ii).positionLabel);

    summary.centerInitial_all(ii,:) = results(ii).centerInitial;
    summary.centerOptimized_all(ii,:) = results(ii).centerOptimized;
    summary.centerShift_all(ii,:) = results(ii).centerShift;

    summary.WG_period_mean_all(ii) = results(ii).WG_period_mean;
    summary.WG_period_std_all(ii)  = results(ii).WG_period_std;
    summary.WG_duty_mean_all(ii)   = results(ii).WG_duty_mean;
    summary.WG_duty_std_all(ii)    = results(ii).WG_duty_std;
    summary.WG_Nperiod_mean_all(ii) = results(ii).WG_Nperiod_mean;
end

end
