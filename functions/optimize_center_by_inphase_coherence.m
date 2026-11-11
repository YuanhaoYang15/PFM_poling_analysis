function opt = optimize_center_by_inphase_coherence(data, center0, cfg)
%OPTIMIZE_CENTER_BY_INPHASE_COHERENCE Find radial spokes, then polish period.

startTime = tic;
cfg = set_default_batch_options(cfg);
usedGlobal = isempty(center0);
if usedGlobal
    centerSource = 'auto';
else
    if numel(center0) ~= 2 || any(~isfinite(center0(:)))
        error('Initial center must be empty or contain two finite coordinates.');
    end
    center0 = double(center0(:).');
    centerSource = 'manual';
end
report_progress_local(cfg, sprintf('CENTER_OPT START mode=coherence source=%s', centerSource));

[centerCoherence, coherence] = find_center_by_stripe_coherence(data, cfg, center0);
if usedGlobal
    centerInitial = centerCoherence;
else
    centerInitial = center0;
end

[centerBest, polish] = polish_center_radial_period(data, centerCoherence, cfg);

N = 2*pi*cfg.design.periodRef.Rref / cfg.design.periodRef.LambdaRef;
rRange = cfg.centerOpt.coherence.radiusRange;
if isempty(rRange)
    rRange = [cfg.radius.rMin, cfg.radius.rMax];
end
rRange = sort(rRange(:).');
[finalJ, finalObjective] = center_stripe_coherence(centerBest, ...
    data.X, data.Y, data.inphase, N, rRange, ...
    cfg.centerOpt.coherence.taper_um, cfg.centerOpt.coherence.minPixels);

reasons = strings(0, 1);
if usedGlobal && coherence.peakRatio < cfg.centerOpt.coherence.minPeakRatio
    reasons(end+1,1) = string(sprintf('Global peak ratio %.4g is below %.4g.', ...
        coherence.peakRatio, cfg.centerOpt.coherence.minPeakRatio));
end
if finalJ < cfg.centerOpt.coherence.minCoherence
    reasons(end+1,1) = string(sprintf('Final stripe coherence %.4g is below %.4g.', ...
        finalJ, cfg.centerOpt.coherence.minCoherence));
end
if coherence.hitWindowEdge
    reasons(end+1,1) = "Local coherence search still reaches its window edge.";
end
if polish.noValidCandidate || ~isfinite(polish.finalPeriodError_um)
    reasons(end+1,1) = "Final period evaluation is not valid.";
elseif abs(polish.finalPeriodError_um) > cfg.centerOpt.coherence.maxFinalPeriodError_um
    reasons(end+1,1) = string(sprintf('Final signed median period error %+.5g um exceeds %.5g um.', ...
        polish.finalPeriodError_um, cfg.centerOpt.coherence.maxFinalPeriodError_um));
end
notes = strings(0, 1);
if ~polish.applied
    notes(end+1,1) = "Radial period polish was not applied: " + string(polish.reason) + ".";
end

opt = struct();
opt.centerInitial = centerInitial;
opt.centerBest = centerBest;
opt.centerShift = centerBest - centerInitial;
opt.bestMetric = polish.bestMetric;
opt.metricMode = cfg.centerOpt.metricMode;
opt.rListOpt = polish.rListOpt;
opt.fitRadiusRange = polish.fitRadiusRange;
opt.lambdaDesign = polish.lambdaDesign;
opt.bestAnalysisOnOptGrid = polish.bestAnalysisOnOptGrid;
opt.passCount = 1;
opt.boundaryWarning = '';
if coherence.hitWindowEdge
    opt.boundaryWarning = 'Local coherence search still reaches its window edge.';
end
opt.mode = 'inphase_coherence_radial_polish';
opt.centerSource = centerSource;
opt.centerCoherence = centerCoherence;
opt.coherence = coherence;
opt.polish = polish;
opt.finalJ = finalJ;
opt.finalObjective = finalObjective;
opt.qc = struct('flag', ~isempty(reasons), 'reasons', reasons, 'notes', notes, ...
    'finalCoherence', finalJ, 'peakRatio', coherence.peakRatio, ...
    'finalPeriodError_um', polish.finalPeriodError_um, 'polishApplied', polish.applied);
opt.time_s = toc(startTime);

report_progress_local(cfg, sprintf([ ...
    'CENTER_OPT DONE source=%s bestCenter=[%.4f, %.4f] J=%.5f ', ...
    'bestMetric=%.6g finalPeriodError=%+.6g polishApplied=%d qc=%d time=%.3fs'], ...
    centerSource, centerBest(1), centerBest(2), finalJ, ...
    opt.bestMetric, polish.finalPeriodError_um, polish.applied, opt.qc.flag, opt.time_s));
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
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s | %s\n', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), msg);
end
