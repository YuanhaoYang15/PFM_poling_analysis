function [center, info] = polish_center_radial_period(data, center, cfg)
%POLISH_CENTER_RADIAL_PERIOD Refine radius from a robust signed-error zero crossing.

cfg = set_default_batch_options(cfg);
if numel(center) ~= 2 || any(~isfinite(center(:)))
    error('Center must contain two finite coordinates.');
end
center = double(center(:).');
centerInput = center;

fitRange = cfg.centerOpt.fitRadiusRange;
if isempty(fitRange)
    fitRange = [cfg.design.R0 - cfg.design.w/2, cfg.design.R0 + cfg.design.w/2];
end
fitRange = sort(fitRange(:).');
rListOpt = max(cfg.radius.rMin, fitRange(1)):cfg.centerOpt.rStep:min(cfg.radius.rMax, fitRange(2));
if isempty(rListOpt)
    rListOpt = cfg.design.R0;
end
lambdaDesign = design_period(rListOpt, cfg);

rRange = cfg.centerOpt.coherence.radiusRange;
if isempty(rRange)
    rRange = [cfg.radius.rMin, cfg.radius.rMax];
end
rRange = sort(rRange(:).');
if numel(rRange) ~= 2 || any(~isfinite(rRange))
    error('Coherence radiusRange must contain two finite radii.');
end
r = hypot(data.X - center(1), data.Y - center(2));
mask = isfinite(data.X) & isfinite(data.Y) & isfinite(data.inphase) & ...
    r >= rRange(1) & r <= rRange(2);
direction = [0, 0];
if any(mask(:))
    delta = [mean(data.X(mask)), mean(data.Y(mask))] - center;
    distance = hypot(delta(1), delta(2));
    if distance > 0 && isfinite(distance)
        direction = delta / distance;
    end
end

range_um = cfg.centerOpt.radialPolish.range_um;
step_um = cfg.centerOpt.radialPolish.step_um;
minSamples = cfg.centerOpt.radialPolish.minSamples;
agreeTolerance_um = cfg.centerOpt.radialPolish.agreeTolerance_um;
minAgreeFraction = cfg.centerOpt.radialPolish.minAgreeFraction;
if ~isscalar(range_um) || ~isfinite(range_um) || range_um < 0 || ...
        ~isscalar(step_um) || ~isfinite(step_um) || step_um <= 0
    error('Radial polish requires a finite nonnegative range and positive step.');
end
if ~isscalar(minSamples) || ~isfinite(minSamples) || minSamples < 1 || ...
        minSamples ~= floor(minSamples) || ~isscalar(agreeTolerance_um) || ...
        ~isfinite(agreeTolerance_um) || agreeTolerance_um < 0 || ...
        ~isscalar(minAgreeFraction) || ~isfinite(minAgreeFraction) || ...
        minAgreeFraction < 0 || minAgreeFraction > 1
    error('Invalid radial polish sample count or agreement settings.');
end
slope = cfg.design.periodRef.LambdaRef / cfg.design.periodRef.Rref;
if ~isscalar(slope) || ~isfinite(slope) || slope <= 0
    error('Radial polish requires a positive finite design period slope.');
end
enabled = logical(cfg.centerOpt.radialPolish.enable);
if ~isscalar(enabled)
    error('Radial polish enable must be scalar.');
end

tList = [];
errorList = [];
metricList = [];
zList = [];
tStar = NaN;
tBest = 0;
applied = false;
reason = 'disabled';
agreeFraction = 0;
if enabled
    tList = -range_um:step_um:range_um;
    errorList = nan(size(tList));
    metricList = inf(size(tList));
    for k = 1:numel(tList)
        if k > 1 && ~any(direction)
            errorList(k) = errorList(1);
            metricList(k) = metricList(1);
            continue;
        end
        candidate = centerInput + tList(k) * direction;
        [~, errorList(k), metricList(k)] = evaluate_center_local( ...
            data, candidate, rListOpt, lambdaDesign, cfg);
    end
    zList = tList - errorList / slope;
    finiteZ = isfinite(zList);
    if nnz(finiteZ) < minSamples
        reason = 'too few valid samples';
    else
        tStar = median(zList(finiteZ));
        agreeFraction = nnz(abs(zList(finiteZ) - tStar) <= agreeTolerance_um) / numel(tList);
        if agreeFraction < minAgreeFraction
            reason = 'inconsistent period response';
        elseif abs(tStar) > range_um
            reason = 'zero crossing outside range';
        else
            tBest = tStar;
            center = centerInput + tBest * direction;
            applied = true;
            reason = '';
        end
    end
end

[finalAnalysis, finalError, finalMetric, finalValid] = evaluate_center_local( ...
    data, center, rListOpt, lambdaDesign, cfg);
zeroIndex = find(tList == 0, 1, 'first');
if ~isempty(zeroIndex)
    e0 = errorList(zeroIndex);
elseif isequal(center, centerInput)
    e0 = finalError;
else
    % A colon grid need not include zero, even when the range is symmetric.
    [~, e0] = evaluate_center_local(data, centerInput, rListOpt, lambdaDesign, cfg);
end

info = struct();
info.tList = tList;
info.errorList = errorList;
info.zList = zList;
info.metricList = metricList;
info.tStar = tStar;
info.tBest = tBest;
info.applied = logical(applied);
info.reason = reason;
info.agreeFraction = agreeFraction;
info.slope = slope;
info.e0 = e0;
info.finalPeriodError_um = finalError;
info.bestMetric = finalMetric;
info.direction = direction;
info.atBoundary = false;
info.noValidCandidate = ~finalValid;
info.enabled = enabled;
info.rListOpt = rListOpt;
info.fitRadiusRange = fitRange;
info.lambdaDesign = lambdaDesign;
info.metricMode = cfg.centerOpt.metricMode;
info.bestAnalysisOnOptGrid = finalAnalysis;
end

function [analysis, signedError, metric, hasValid] = evaluate_center_local( ...
        data, center, rListOpt, lambdaDesign, cfg)
analysis = extract_inphase_duty_vs_radius(data, center, rListOpt, cfg);
periodMean = analysis.periodMean(:).';
periodStd = analysis.periodStd(:).';
nPeriods = analysis.nPeriods(:).';
lambdaDesign = lambdaDesign(:).';
valid = isfinite(periodMean) & isfinite(lambdaDesign);
valid = valid & nPeriods >= cfg.centerOpt.minNPeriods;
valid = valid & periodStd <= cfg.centerOpt.maxPeriodStd_um;
valid = valid & abs(periodMean - lambdaDesign) <= cfg.centerOpt.maxAbsPeriodError_um;
signedError = NaN;
metric = Inf;
hasValid = nnz(valid) >= cfg.centerOpt.minValidRadii;
if ~hasValid
    return;
end
err = periodMean(valid) - lambdaDesign(valid);
signedError = median(err);
metric = center_metric_local(err, cfg.centerOpt.metricMode);
if ~isfinite(signedError) || ~isfinite(metric)
    signedError = NaN;
    metric = Inf;
    hasValid = false;
end
end

function metric = center_metric_local(err, metricMode)
switch lower(metricMode)
    case {'median_abs','median'}
        metric = median(abs(err), 'omitnan');
    case {'rmse','rms'}
        metric = sqrt(mean(err.^2, 'omitnan'));
    case {'mean_abs','mae'}
        metric = mean(abs(err), 'omitnan');
    otherwise
        error('Unknown cfg.centerOpt.metricMode: %s', metricMode);
end
end
