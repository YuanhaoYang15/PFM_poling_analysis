function result = analyze_one_pfm_scan(cfg, scanCfg)
%ANALYZE_ONE_PFM_SCAN Analyze one PFM scan.
%
% The input scan can point directly to a raw txt folder/file.
% Preprocessing is done automatically by load_pfm_data().

data = load_pfm_data(cfg, scanCfg);

rList = cfg.radius.rMin:cfg.radius.dr:cfg.radius.rMax;
center0 = resolve_initial_center(cfg, scanCfg);

fprintf('Initial center: [%.4f, %.4f] um\n', center0(1), center0(2));

analysis0 = extract_period_duty_vs_radius(data, center0, rList, cfg);

if cfg.centerOpt.enable
    opt = optimize_center_by_period(data, center0, cfg);
    centerBest = opt.centerBest;
    fprintf('Optimized center: [%.4f, %.4f] um\n', centerBest(1), centerBest(2));
    fprintf('Center shift:     [%.4f, %.4f] um\n', centerBest(1)-center0(1), centerBest(2)-center0(2));
else
    opt = struct();
    centerBest = center0;
end

analysis = extract_period_duty_vs_radius(data, centerBest, rList, cfg);

wgMask = rList >= cfg.design.R0 - cfg.design.w/2 & rList <= cfg.design.R0 + cfg.design.w/2;

result = struct();
result.rawName = getfield_or(scanCfg, 'rawName', getfield_or(scanCfg, 'fileName', ''));
result.rawFileName = result.rawName;  % compatibility with v1 plotting
result.sourceFile = data.sourceFile;
result.deviceName = cfg.deviceName;
result.scanID = scanCfg.scanID;
result.positionLabel = getfield_or(scanCfg, 'positionLabel', '');
result.notes = getfield_or(scanCfg, 'notes', '');

result.data = data;

result.centerInitial = center0;
result.centerOptimized = centerBest;
result.centerShift = centerBest - center0;
result.centerOpt = opt;

result.radiusList = rList;

result.before = analysis0;
result.after = analysis;

result.WG_mask = wgMask;
result.WG_period_mean = mean(analysis.periodMean(wgMask), 'omitnan');
result.WG_period_std  = std(analysis.periodMean(wgMask), 'omitnan');
result.WG_period_err_mean = mean(analysis.periodStd(wgMask), 'omitnan');

result.WG_duty_mean = mean(analysis.dutyMean(wgMask), 'omitnan');
result.WG_duty_std  = std(analysis.dutyMean(wgMask), 'omitnan');
result.WG_duty_err_mean = mean(analysis.dutyStd(wgMask), 'omitnan');

result.WG_Nperiod_mean = mean(analysis.nPeriods(wgMask), 'omitnan');

result.configUsed = cfg;
result.scanConfigUsed = scanCfg;

end
