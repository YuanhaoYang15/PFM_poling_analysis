function opt = optimize_center_by_inphase_period(data, center0, cfg)
%OPTIMIZE_CENTER_BY_INPHASE_PERIOD Center correction from inphase period.

cfg = set_default_batch_options(cfg);

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

searchRange = cfg.centerOpt.searchRange;
searchStep = cfg.centerOpt.searchStep;
dxList = make_offset_list_local(-searchRange, searchRange, searchStep);
dyList = make_offset_list_local(-searchRange, searchRange, searchStep);

pass1 = run_center_pass_local(data, center0, dxList, dyList, cfg, ...
    fitRange, rListOpt, lambdaDesign, 1);
pass1.boundary = detect_pass_boundary_local(pass1, cfg);

passes = pass1;
finalPass = pass1;
boundaryWarning = "";

canRefine = cfg.centerOpt.edgeRefine.enable && ...
    cfg.centerOpt.edgeRefine.maxPasses >= 2 && ...
    pass1.hasValidCandidate && pass_hits_boundary_local(pass1.boundary);

if canRefine
    refineRange = searchRange * cfg.centerOpt.edgeRefine.rangeScale;
    [dxRefine, xBounds] = make_refine_offsets_local( ...
        pass1.boundary.xDirection, refineRange, cfg);
    [dyRefine, yBounds] = make_refine_offsets_local( ...
        pass1.boundary.yDirection, refineRange, cfg);

    report_progress_local(cfg, sprintf([ ...
        'CENTER_OPT PASS 2 RECENTER firstShift=[%.3f, %.3f] ', ...
        'xBounds=[%.3f, %.3f] yBounds=[%.3f, %.3f]'], ...
        pass1.centerBest(1) - center0(1), pass1.centerBest(2) - center0(2), ...
        xBounds(1), xBounds(2), yBounds(1), yBounds(2)));

    pass2 = run_center_pass_local(data, pass1.centerBest, dxRefine, dyRefine, cfg, ...
        fitRange, rListOpt, lambdaDesign, 2);
    pass2.boundary = detect_pass_boundary_local(pass2, cfg);
    pass2.recenteredFromPass = 1;
    passes(2) = pass2;

    if pass2.hasValidCandidate
        finalPass = pass2;
    end

    outwardHit = outward_boundary_hit_local(pass1.boundary, pass2.boundary);
    if outwardHit.x || outwardHit.y
        axesLabel = boundary_axes_label_local(outwardHit);
        boundaryWarning = sprintf([ ...
            'Inphase center optimization still reached the outward refinement boundary on %s. ', ...
            'Consider re-picking the manual center.'], axesLabel);
        warning('%s', boundaryWarning);
        report_progress_local(cfg, ['CENTER_OPT WARNING ', boundaryWarning]);
    end
end

opt = pass_to_opt_local(finalPass, center0, cfg, fitRange, rListOpt, lambdaDesign);
opt.mode = 'inphase_period_edge_refine';
opt.passes = passes;
opt.passCount = numel(passes);
opt.boundaryWarning = boundaryWarning;
opt.edgeRefine = cfg.centerOpt.edgeRefine;

if ~finalPass.hasValidCandidate
    warning('Inphase center optimization found no valid candidate. Keeping initial center.');
    opt.centerBest = center0;
    opt.centerShift = [0, 0];
end

report_progress_local(cfg, sprintf([ ...
    'CENTER_OPT DONE passes=%d bestMetric=%s bestCenter=[%.4f, %.4f] ', ...
    'shiftFromManual=[%.3f, %.3f]'], ...
    opt.passCount, format_metric_local(opt.bestMetric), ...
    opt.centerBest(1), opt.centerBest(2), opt.centerShift(1), opt.centerShift(2)));
end

function pass = run_center_pass_local(data, anchorCenter, dxList, dyList, cfg, ...
        fitRange, rListOpt, lambdaDesign, passIndex)
metricMap = nan(numel(dyList), numel(dxList));
periodErrMap = nan(size(metricMap));
periodStdMap = nan(size(metricMap));
nPeriodMap = nan(size(metricMap));
validCountMap = nan(size(metricMap));

bestMetric = inf;
bestCenter = anchorCenter;
bestAnalysis = [];

report_progress_local(cfg, sprintf([ ...
    'CENTER_OPT PASS %d START grid=%dx%d candidates=%d ', ...
    'fitR=[%.3f, %.3f] radii=%d xOffsets=[%.3f, %.3f] yOffsets=[%.3f, %.3f]'], ...
    passIndex, numel(dxList), numel(dyList), numel(dxList) * numel(dyList), ...
    fitRange(1), fitRange(2), numel(rListOpt), ...
    min(dxList), max(dxList), min(dyList), max(dyList)));

progressRowStep = max(1, ceil(numel(dyList) / 20));
for iy = 1:numel(dyList)
    for ix = 1:numel(dxList)
        center = anchorCenter + [dxList(ix), dyList(iy)];
        ana = extract_inphase_duty_vs_radius(data, center, rListOpt, cfg);

        valid = isfinite(ana.periodMean) & isfinite(lambdaDesign);
        valid = valid & ana.nPeriods >= cfg.centerOpt.minNPeriods;
        valid = valid & ana.periodStd <= cfg.centerOpt.maxPeriodStd_um;
        valid = valid & abs(ana.periodMean - lambdaDesign) <= cfg.centerOpt.maxAbsPeriodError_um;
        if nnz(valid) < cfg.centerOpt.minValidRadii
            continue;
        end

        err = ana.periodMean(valid) - lambdaDesign(valid);
        metric = center_metric_local(err, cfg.centerOpt.metricMode);

        metricMap(iy, ix) = metric;
        periodErrMap(iy, ix) = mean(err, 'omitnan');
        periodStdMap(iy, ix) = mean(ana.periodStd(valid), 'omitnan');
        nPeriodMap(iy, ix) = mean(ana.nPeriods(valid), 'omitnan');
        validCountMap(iy, ix) = nnz(valid);

        if metric < bestMetric
            bestMetric = metric;
            bestCenter = center;
            bestAnalysis = ana;
        end
    end

    if iy == 1 || iy == numel(dyList) || mod(iy, progressRowStep) == 0
        report_progress_local(cfg, sprintf([ ...
            'CENTER_OPT PASS %d %3.0f%% rows=%d/%d candidates=%d/%d ', ...
            'bestMetric=%s bestShiftFromPass=[%.3f, %.3f]'], ...
            passIndex, 100 * iy / numel(dyList), iy, numel(dyList), ...
            iy * numel(dxList), numel(dxList) * numel(dyList), ...
            format_metric_local(bestMetric), ...
            bestCenter(1) - anchorCenter(1), bestCenter(2) - anchorCenter(2)));
    end
end

pass = struct();
pass.index = passIndex;
pass.anchorCenter = anchorCenter;
pass.centerBest = bestCenter;
pass.centerShiftFromPass = bestCenter - anchorCenter;
pass.bestMetric = bestMetric;
pass.hasValidCandidate = isfinite(bestMetric);
pass.dxList = dxList;
pass.dyList = dyList;
pass.metricMap = metricMap;
pass.periodErrMap = periodErrMap;
pass.periodStdMap = periodStdMap;
pass.nPeriodMap = nPeriodMap;
pass.validCountMap = validCountMap;
pass.bestAnalysisOnOptGrid = bestAnalysis;
pass.recenteredFromPass = NaN;
end

function opt = pass_to_opt_local(pass, center0, cfg, fitRange, rListOpt, lambdaDesign)
opt = struct();
opt.centerInitial = center0;
opt.centerBest = pass.centerBest;
opt.centerShift = pass.centerBest - center0;
opt.bestMetric = pass.bestMetric;
opt.dxList = pass.dxList;
opt.dyList = pass.dyList;
opt.metricMap = pass.metricMap;
opt.periodErrMap = pass.periodErrMap;
opt.periodStdMap = pass.periodStdMap;
opt.nPeriodMap = pass.nPeriodMap;
opt.validCountMap = pass.validCountMap;
opt.rListOpt = rListOpt;
opt.fitRadiusRange = fitRange;
opt.lambdaDesign = lambdaDesign;
opt.bestAnalysisOnOptGrid = pass.bestAnalysisOnOptGrid;
opt.metricMode = cfg.centerOpt.metricMode;
end

function offsets = make_offset_list_local(minOffset, maxOffset, step)
offsets = unique([minOffset:step:maxOffset, minOffset, 0, maxOffset]);
offsets = sort(offsets);
end

function [offsets, bounds] = make_refine_offsets_local(boundaryDirection, refineRange, cfg)
outwardFraction = cfg.centerOpt.edgeRefine.outwardFraction;
outwardExtent = refineRange * outwardFraction;
inwardExtent = refineRange * (1 - outwardFraction);

if boundaryDirection > 0
    bounds = [-inwardExtent, outwardExtent];
elseif boundaryDirection < 0
    bounds = [-outwardExtent, inwardExtent];
else
    halfWidth = refineRange / 2;
    bounds = [-halfWidth, halfWidth];
end

offsets = make_offset_list_local(bounds(1), bounds(2), cfg.centerOpt.searchStep);
end

function boundary = detect_pass_boundary_local(pass, cfg)
boundary = struct('xDirection', 0, 'yDirection', 0, ...
    'xNearMin', false, 'xNearMax', false, ...
    'yNearMin', false, 'yNearMax', false);

if ~pass.hasValidCandidate
    return;
end

tol = cfg.centerOpt.searchStep * cfg.centerOpt.edgeRefine.boundaryStepTolerance;
[boundary.xDirection, boundary.xNearMin, boundary.xNearMax] = ...
    detect_axis_boundary_local(pass.centerShiftFromPass(1), pass.dxList, tol);
[boundary.yDirection, boundary.yNearMin, boundary.yNearMax] = ...
    detect_axis_boundary_local(pass.centerShiftFromPass(2), pass.dyList, tol);
end

function [direction, nearMin, nearMax] = detect_axis_boundary_local(offset, offsets, tol)
minOffset = min(offsets);
maxOffset = max(offsets);
epsTol = max(eps(max(abs(offsets))), eps(abs(offset)));
nearMin = offset - minOffset <= tol + epsTol;
nearMax = maxOffset - offset <= tol + epsTol;

direction = 0;
if nearMin && nearMax
    if abs(offset - minOffset) <= abs(maxOffset - offset)
        direction = -1;
    else
        direction = 1;
    end
elseif nearMin
    direction = -1;
elseif nearMax
    direction = 1;
end
end

function tf = pass_hits_boundary_local(boundary)
tf = boundary.xDirection ~= 0 || boundary.yDirection ~= 0;
end

function hit = outward_boundary_hit_local(firstBoundary, secondBoundary)
hit = struct();
hit.x = firstBoundary.xDirection ~= 0 && ...
    secondBoundary.xDirection == firstBoundary.xDirection;
hit.y = firstBoundary.yDirection ~= 0 && ...
    secondBoundary.yDirection == firstBoundary.yDirection;
end

function label = boundary_axes_label_local(hit)
parts = strings(0,1);
if hit.x; parts(end+1,1) = "x"; end %#ok<AGROW>
if hit.y; parts(end+1,1) = "y"; end %#ok<AGROW>
label = char(strjoin(parts, ' and '));
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

function report_progress_local(cfg, msg)
if isfield(cfg, 'progress') && isfield(cfg.progress, 'scanLabel') && ~isempty(cfg.progress.scanLabel)
    msg = sprintf('%s | %s', cfg.progress.scanLabel, msg);
end

fprintf('%s\n', msg);

if ~isfield(cfg, 'progress') || ~isfield(cfg.progress, 'logFile') || isempty(cfg.progress.logFile)
    return;
end

fid = fopen(cfg.progress.logFile, 'a');
if fid < 0
    warning('Cannot open progress log: %s', cfg.progress.logFile);
    return;
end
fprintf(fid, '%s | %s\n', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), msg);
fclose(fid);
end

function label = format_metric_local(metric)
if isfinite(metric)
    label = sprintf('%.6g', metric);
else
    label = 'Inf';
end
end
