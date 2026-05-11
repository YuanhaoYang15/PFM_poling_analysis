function opt = optimize_center_by_period(data, center0, cfg)
%OPTIMIZE_CENTER_BY_PERIOD Controlled period-based center correction.
%
% This optimizer uses only a selected radius range, normally the waveguide
% region or cfg.centerOpt.fitRadiusRange. It minimizes period error relative
% to the design curve. Duty cycle is never used.

cfg = set_default_batch_options(cfg);

dxList = -cfg.centerOpt.searchRange:cfg.centerOpt.searchStep:cfg.centerOpt.searchRange;
dyList = -cfg.centerOpt.searchRange:cfg.centerOpt.searchStep:cfg.centerOpt.searchRange;

fitRange = cfg.centerOpt.fitRadiusRange;
if isempty(fitRange)
    fitRange = [cfg.design.R0 - cfg.design.w/2, cfg.design.R0 + cfg.design.w/2];
end
fitRange = sort(fitRange);

rListOpt = max(cfg.radius.rMin, fitRange(1)):cfg.centerOpt.rStep:min(cfg.radius.rMax, fitRange(2));
if isempty(rListOpt)
    rListOpt = cfg.design.R0;
end
lambdaDesign = design_period(rListOpt, cfg);

metricMap = nan(numel(dyList), numel(dxList));
periodErrMap = nan(size(metricMap));
periodStdMap = nan(size(metricMap));
nPeriodMap = nan(size(metricMap));
validCountMap = nan(size(metricMap));

bestMetric = inf;
bestCenter = center0;
bestAnalysis = [];

fprintf('Center optimization grid: %d x %d candidates\n', numel(dxList), numel(dyList));
fprintf('Center optimization fit radius range: [%.3f, %.3f] um, %d radii\n', ...
    fitRange(1), fitRange(2), numel(rListOpt));

for iy = 1:numel(dyList)
    for ix = 1:numel(dxList)
        c = center0 + [dxList(ix), dyList(iy)];
        ana = extract_period_duty_vs_radius(data, c, rListOpt, cfg);

        valid = isfinite(ana.periodMean) & isfinite(lambdaDesign);
        valid = valid & ana.nPeriods >= cfg.centerOpt.minNPeriods;
        valid = valid & ana.periodStd <= cfg.centerOpt.maxPeriodStd_um;
        valid = valid & abs(ana.periodMean - lambdaDesign) <= cfg.centerOpt.maxAbsPeriodError_um;

        if nnz(valid) < cfg.centerOpt.minValidRadii
            continue;
        end

        err = ana.periodMean(valid) - lambdaDesign(valid);

        switch lower(cfg.centerOpt.metricMode)
            case {'median_abs','median'}
                metric = median(abs(err), 'omitnan');
            case {'rmse','rms'}
                metric = sqrt(mean(err.^2, 'omitnan'));
            case {'mean_abs','mae'}
                metric = mean(abs(err), 'omitnan');
            otherwise
                error('Unknown cfg.centerOpt.metricMode: %s', cfg.centerOpt.metricMode);
        end

        metricMap(iy, ix) = metric;
        periodErrMap(iy, ix) = mean(err, 'omitnan');
        periodStdMap(iy, ix) = mean(ana.periodStd(valid), 'omitnan');
        nPeriodMap(iy, ix) = mean(ana.nPeriods(valid), 'omitnan');
        validCountMap(iy, ix) = nnz(valid);

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
opt.validCountMap = validCountMap;
opt.rListOpt = rListOpt;
opt.fitRadiusRange = fitRange;
opt.lambdaDesign = lambdaDesign;
opt.bestAnalysisOnOptGrid = bestAnalysis;
opt.metricMode = cfg.centerOpt.metricMode;

if ~isfinite(bestMetric)
    warning('Center optimization failed to find a valid candidate. Keeping initial center.');
    opt.centerBest = center0;
    opt.centerShift = [0, 0];
end
end
