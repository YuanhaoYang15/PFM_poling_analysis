function opt = optimize_center_by_period(data, center0, cfg)
%OPTIMIZE_CENTER_BY_PERIOD Optimize center using designed period curve.

dxList = -cfg.centerOpt.searchRange:cfg.centerOpt.searchStep:cfg.centerOpt.searchRange;
dyList = -cfg.centerOpt.searchRange:cfg.centerOpt.searchStep:cfg.centerOpt.searchRange;

rListOpt = cfg.radius.rMin:cfg.centerOpt.rStep:cfg.radius.rMax;
lambdaDesign = design_period(rListOpt, cfg);

metricMap = nan(numel(dyList), numel(dxList));
periodErrMap = nan(size(metricMap));
periodStdMap = nan(size(metricMap));
nPeriodMap = nan(size(metricMap));

bestMetric = inf;
bestCenter = center0;
bestAnalysis = [];

fprintf('Center optimization grid: %d x %d candidates\n', numel(dxList), numel(dyList));

for iy = 1:numel(dyList)
    for ix = 1:numel(dxList)
        c = center0 + [dxList(ix), dyList(iy)];

        ana = extract_period_duty_vs_radius(data, c, rListOpt, cfg);

        valid = ~isnan(ana.periodMean) & ~isnan(lambdaDesign);
        if nnz(valid) < max(3, round(0.3*numel(rListOpt)))
            continue;
        end

        err = ana.periodMean(valid) - lambdaDesign(valid);
        rmse = sqrt(mean(err.^2, 'omitnan'));

        meanStd = mean(ana.periodStd(valid), 'omitnan');
        if isnan(meanStd); meanStd = 0; end

        meanN = mean(ana.nPeriods(valid), 'omitnan');
        if isnan(meanN); meanN = 0; end

        % Prefer low period error, low period STD, and enough detected periods.
        metric = cfg.centerOpt.weightPeriodError * rmse ...
               + cfg.centerOpt.weightPeriodStd * meanStd ...
               + cfg.centerOpt.weightNperiod * 1/max(meanN, 1);

        metricMap(iy, ix) = metric;
        periodErrMap(iy, ix) = rmse;
        periodStdMap(iy, ix) = meanStd;
        nPeriodMap(iy, ix) = meanN;

        if metric < bestMetric
            bestMetric = metric;
            bestCenter = c;
            bestAnalysis = ana;
        end
    end
end

opt = struct();
opt.centerInitial = center0;
opt.centerBest = bestCenter;
opt.centerShift = bestCenter - center0;
opt.bestMetric = bestMetric;
opt.dxList = dxList;
opt.dyList = dyList;
opt.metricMap = metricMap;
opt.periodErrMap = periodErrMap;
opt.periodStdMap = periodStdMap;
opt.nPeriodMap = nPeriodMap;
opt.rListOpt = rListOpt;
opt.lambdaDesign = lambdaDesign;
opt.bestAnalysisOnOptGrid = bestAnalysis;

end
