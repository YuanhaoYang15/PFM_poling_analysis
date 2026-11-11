function test_center_coherence_synthetic()
%TEST_CENTER_COHERENCE_SYNTHETIC Recover known spoke centers without clicks.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
oldPath = path;
pathCleanup = onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(fullfile(projectRoot, 'functions'));
outRoot = fullfile(projectRoot, 'local', 'regression_out');
if ~exist(outRoot, 'dir'); mkdir(outRoot); end
oldRng = rng;
rngCleanup = onCleanup(@() rng(oldRng)); %#ok<NASGU>
rng(27401, 'twister');
oldThreads = maxNumCompThreads(1);
threadCleanup = onCleanup(@() maxNumCompThreads(oldThreads)); %#ok<NASGU>

failures = 0;
geometry = [40, 2.75, 30; 30, 3.0, 20; 50, 2.5, 30];
directions = [-1, 0; 1, 0; 0, -1; 0, 1; -sqrt(0.5), -sqrt(0.5)];
names = {'left', 'right', 'above', 'below', 'diagonal'};
rows = cell(15, 16);
caseIndex = 0;
for ig = 1:size(geometry, 1)
    R0 = geometry(ig, 1);
    lambda = geometry(ig, 2);
    fov = geometry(ig, 3);
    for id = 1:size(directions, 1)
        caseIndex = caseIndex + 1;
        label = sprintf('R0=%.2f Lambda=%.2f FOV=%.2f %s', R0, lambda, fov, names{id});
        direction = directions(id, :);
        tangent = [-direction(2), direction(1)];
        truth = [fov/2, fov/2] + (R0 + 0.8)*direction + 2.1*tangent;
        start = truth + 3*[0.6, 0.8];
        cfg = synthetic_cfg_local(R0, lambda);
        data = synthetic_image_local(fov, truth, R0, lambda);
        fprintf('\nCASE %02d %s truth=[%.8f %.8f] start=[%.8f %.8f]\n', ...
            caseIndex, label, truth, start);
        auto = [];
        manual = [];
        errAuto = NaN;
        errManual = NaN;
        periodAuto = NaN;
        periodManual = NaN;
        try
            auto = optimize_center_by_inphase_coherence(data, [], cfg);
            errAuto = norm(auto.centerBest - truth);
            fprintf('AUTO coherenceCenter=[%.8f %.8f] final=[%.8f %.8f] J=%.8f peakRatio=%.8f polish=%.5f qc=%d reasons=%s time=%.3f s\n', ...
                auto.centerCoherence, auto.centerBest, auto.coherence.J, ...
                auto.coherence.peakRatio, auto.polish.tBest, auto.qc.flag, ...
                char(reasons_text_local(auto.qc.reasons)), auto.time_s);
            failures = failures + check_local(errAuto <= 0.10, ...
                sprintf('B1 %s center error %.8f um <= 0.10 um', label, errAuto));
            failures = failures + check_local(~auto.qc.flag, ...
                sprintf('B1 %s qc.flag=%d expected false', label, auto.qc.flag));
            [periodAuto, nValidAuto] = wg_error_local(data, auto.centerBest, cfg);
            failures = failures + check_local(isfinite(periodAuto) && abs(periodAuto) <= 0.01, ...
                sprintf('B3 AUTO %s WG error=%+.8f um expected |error|<=0.01 (%d valid radii)', ...
                label, periodAuto, nValidAuto));
        catch exception
            failures = failures + 1;
            fprintf('FAIL B1/B3 AUTO %s: %s\n%s\n', label, exception.message, ...
                getReport(exception, 'extended', 'hyperlinks', 'off'));
        end
        try
            manual = optimize_center_by_inphase_coherence(data, start, cfg);
            errManual = norm(manual.centerBest - truth);
            fprintf('GIVEN coherenceCenter=[%.8f %.8f] final=[%.8f %.8f] J=%.8f polish=%.5f qc=%d reasons=%s time=%.3f s\n', ...
                manual.centerCoherence, manual.centerBest, manual.coherence.J, ...
                manual.polish.tBest, manual.qc.flag, char(reasons_text_local(manual.qc.reasons)), manual.time_s);
            failures = failures + check_local(errManual <= 0.10, ...
                sprintf('B2 %s center error %.8f um <= 0.10 um', label, errManual));
            failures = failures + check_local(~manual.qc.flag, ...
                sprintf('B2 %s qc.flag=%d expected false', label, manual.qc.flag));
            [periodManual, nValidManual] = wg_error_local(data, manual.centerBest, cfg);
            failures = failures + check_local(isfinite(periodManual) && abs(periodManual) <= 0.01, ...
                sprintf('B3 GIVEN %s WG error=%+.8f um expected |error|<=0.01 (%d valid radii)', ...
                label, periodManual, nValidManual));
        catch exception
            failures = failures + 1;
            fprintf('FAIL B2/B3 GIVEN %s: %s\n%s\n', label, exception.message, ...
                getReport(exception, 'extended', 'hyperlinks', 'off'));
        end
        cAuto = [NaN, NaN];
        cManual = [NaN, NaN];
        qAuto = true;
        qManual = true;
        if ~isempty(auto); cAuto = auto.centerBest; qAuto = auto.qc.flag; end
        if ~isempty(manual); cManual = manual.centerBest; qManual = manual.qc.flag; end
        rows(caseIndex, :) = {R0, lambda, fov, string(names{id}), truth(1), truth(2), ...
            cAuto(1), cAuto(2), cManual(1), cManual(2), errAuto, errManual, ...
            periodAuto, periodManual, qAuto, qManual};
        if ~isfinite(errAuto) || errAuto > 0.10 || ~isfinite(errManual) || errManual > 0.10
            try
                caseFile = fullfile(outRoot, sprintf('synthetic_case_%02d.mat', caseIndex));
                save(caseFile, 'data', 'cfg', 'truth', 'start', 'auto', 'manual');
                fprintf('DIAGNOSTIC CASE %02d saved=%s\n', caseIndex, caseFile);
                diagnose_opt_local(auto, truth, sprintf('CASE %02d AUTO', caseIndex));
                diagnose_opt_local(manual, truth, sprintf('CASE %02d GIVEN', caseIndex));
                [trueMetric, trueValid, trueRadii, trueErrors] = legacy_metric_local(data, truth, cfg);
                trueMedian = NaN;
                if trueValid >= cfg.centerOpt.minValidRadii; trueMedian = median(trueErrors); end
                fprintf('DIAGNOSTIC CASE %02d TRUTH signedMedian=%.12g legacyMetric=%.12g mode=%s validRadii=%d/%d radii=%s validPeriodErrors=%s\n', ...
                    caseIndex, trueMedian, trueMetric, cfg.centerOpt.metricMode, trueValid, numel(trueRadii), ...
                    mat2str(trueRadii, 12), mat2str(trueErrors, 12));
            catch exception
                fprintf('DIAGNOSTIC ERROR CASE %02d: %s\n%s\n', caseIndex, exception.message, ...
                    getReport(exception, 'extended', 'hyperlinks', 'off'));
            end
        end
    end
end
result = cell2table(rows, 'VariableNames', {'R0_um','Lambda_um','FOV_um','direction', ...
    'truthX_um','truthY_um','autoX_um','autoY_um','givenX_um','givenY_um', ...
    'autoError_um','givenError_um','autoWGError_um','givenWGError_um','autoQC','givenQC'});
writetable(result, fullfile(outRoot, 'center_synthetic.csv'));
failures = failures + missing_spoke_checks_local(geometry, outRoot);
failures = failures + objective_checks_local();
failures = failures + polish_checks_local();
fprintf('SYNTHETIC MAX ERRORS centerAuto=%.12g um centerGiven=%.12g um |B3Auto|=%.12g um |B3Given|=%.12g um nonfinite=[%d %d %d %d]\n', ...
    max_absolute_local(result.autoError_um), max_absolute_local(result.givenError_um), ...
    max_absolute_local(result.autoWGError_um), max_absolute_local(result.givenWGError_um), ...
    nnz(~isfinite(result.autoError_um)), nnz(~isfinite(result.givenError_um)), ...
    nnz(~isfinite(result.autoWGError_um)), nnz(~isfinite(result.givenWGError_um)));
fprintf('\nSynthetic checks finished: %d failed hard checks; CSV=%s\n', ...
    failures, fullfile(outRoot, 'center_synthetic.csv'));
if failures > 0
    error('test_center_coherence_synthetic:Failed', '%d synthetic hard checks failed.', failures);
end
fprintf('PASS test_center_coherence_synthetic\n');
end

function cfg = synthetic_cfg_local(R0, lambda)
cfg = struct();
cfg.design = struct('R0', R0, 'w', 1, ...
    'periodRef', struct('Rref', R0, 'LambdaRef', lambda));
cfg.radius = struct('rMin', R0 - 2, 'rMax', R0 + 5, 'dr', 0.1);
cfg = set_default_batch_options(cfg);
end

function data = synthetic_image_local(fov, center, R0, lambda)
[X, Y] = meshgrid(linspace(0, fov, 256));
dx = X - center(1);
dy = Y - center(2);
r = hypot(dx, dy);
thetaRef = atan2(fov/2 - center(2), fov/2 - center(1));
theta = angle((dx + 1i*dy)*exp(-1i*thetaRef));
N = 2*pi*R0/lambda;
phase = N*theta + 0.37;
duty = 0.35;
phaseSmooth = N*(fov/255)/R0;
spokes = -0.5*tanh((cos(phase) - cos(pi*duty))/(sin(pi*duty)*phaseSmooth));
spokes(r < R0 - 4 | r > R0 + 8) = 0;
band = 0.35*exp(-0.5*((r - (R0 + 3))/0.3).^2);
I = spokes + band + 0.25*randn(size(X));
data = struct('X', X, 'Y', Y, 'inphase', I, 'phase', I);
end

function failures = missing_spoke_checks_local(geometry, outRoot)
failures = 0;
rows = cell(size(geometry, 1), 15);
for ig = 1:size(geometry, 1)
    R0 = geometry(ig, 1);
    lambda = geometry(ig, 2);
    fov = geometry(ig, 3);
    truth = [fov/2-(R0+0.8), fov/2-2.1];
    cfg = synthetic_cfg_local(R0, lambda);
    data = synthetic_image_local(fov, truth, R0, lambda);
    r = hypot(data.X-truth(1), data.Y-truth(2));
    thetaRef = atan2(fov/2-truth(2), fov/2-truth(1));
    theta = angle(((data.X-truth(1))+1i*(data.Y-truth(2)))*exp(-1i*thetaRef));
    N = 2*pi*R0/lambda;
    phase = N*theta+0.37;
    phaseSmooth = N*(fov/255)/R0;
    cleanSpokes = -0.5*tanh((cos(phase)-cos(pi*0.35))/(sin(pi*0.35)*phaseSmooth));
    % Replacing one full angular period preserves its high plateau and removes
    % only its central low spoke; adding the correction retains the noise.
    removed = r >= R0-2 & r <= R0+2 & abs(phase) <= pi;
    data.inphase(removed) = data.inphase(removed)+0.5-cleanSpokes(removed);
    data.phase = data.inphase;
    label = sprintf('MISSING R0=%.2f Lambda=%.2f FOV=%.2f', R0, lambda, fov);
    center = [NaN, NaN];
    err = NaN;
    qc = true;
    reason = "optimizer did not return";
    finalMedian = NaN;
    tBest = NaN;
    tStar = NaN;
    agree = NaN;
    opt = [];
    fprintf('\nCASE %s truth=[%.8f %.8f] removedAngularPeriod=0 radialRange=[%.4f %.4f] correctedPixels=%d\n', ...
        label, truth, R0-2, R0+2, nnz(removed));
    try
        opt = optimize_center_by_inphase_coherence(data, [], cfg);
        center = opt.centerBest;
        err = norm(center-truth);
        qc = opt.qc.flag;
        reason = string(opt.polish.reason);
        finalMedian = opt.polish.finalPeriodError_um;
        tBest = opt.polish.tBest;
        tStar = opt.polish.tStar;
        agree = opt.polish.agreeFraction;
        failures = failures + check_local(err <= 0.10, ...
            sprintf('%s click-free center error=%.12g um expected <=0.10 um', label, err));
        fprintf('REPORT %s coherenceCenter=[%.8f %.8f] finalCenter=[%.8f %.8f] qc=%d reasons=%s notes=%s polishApplied=%d polishReason=%s finalMedian=%+.12g tBest=%+.12g tStar=%+.12g agree=%.6f\n', ...
            label, opt.centerCoherence, center, qc, char(reasons_text_local(opt.qc.reasons)), ...
            char(reasons_text_local(opt.qc.notes)), opt.polish.applied, char(reason), finalMedian, tBest, tStar, agree);
        diagnose_opt_local(opt, truth, label);
    catch exception
        failures = failures + 1;
        fprintf('FAIL %s: %s\n%s\n', label, exception.message, ...
            getReport(exception, 'extended', 'hyperlinks', 'off'));
    end
    if ~isfinite(err) || err > 0.10
        auto = opt;
        manual = [];
        start = [];
        caseFile = fullfile(outRoot, sprintf('synthetic_case_%02d.mat', 15+ig));
        try
            save(caseFile, 'data', 'cfg', 'truth', 'start', 'auto', 'manual');
            fprintf('DIAGNOSTIC missing-spoke case saved=%s\n', caseFile);
        catch exception
            fprintf('DIAGNOSTIC ERROR saving %s: %s\n', caseFile, exception.message);
        end
    end
    rows(ig, :) = {R0, lambda, fov, truth(1), truth(2), center(1), center(2), ...
        err, qc, reason, finalMedian, tBest, tStar, agree, nnz(removed)};
end
result = cell2table(rows, 'VariableNames', {'R0_um','Lambda_um','FOV_um','truthX_um','truthY_um', ...
    'autoX_um','autoY_um','autoError_um','qc','polishReason','finalPeriodError_um', ...
    'tBest_um','tStar_um','agreeFraction','correctedPixels'});
writetable(result, fullfile(outRoot, 'center_synthetic_missing_spoke.csv'));
fprintf('MISSING-SPOKE SUMMARY hardFailures=%d maxCenterError=%.12g um; qc, polish reason and final median are report-only\n', ...
    failures, max_absolute_local(result.autoError_um));
end

function [err, nValid] = wg_error_local(data, center, cfg)
radii = cfg.design.R0-cfg.design.w/2:cfg.radius.dr:cfg.design.R0+cfg.design.w/2;
analysis = extract_inphase_duty_vs_radius(data, center, radii, cfg);
valid = isfinite(analysis.periodMean);
nValid = nnz(valid);
err = mean(analysis.periodMean(valid) - design_period(radii(valid), cfg));
end

function diagnose_opt_local(opt, truth, label)
if isempty(opt)
    fprintf('DIAGNOSTIC %s optimizer result unavailable\n', label);
    return;
end
polish = opt.polish;
fprintf('DIAGNOSTIC %s coherenceError=%.12g um finalError=%.12g um e0=%+.12g tStar=%+.12g appliedT=%+.12g applied=%d reason=%s agreeFraction=%.12g finalMedian=%+.12g legacyMetric=%.12g direction=[%.12g %.12g]\n', ...
    label, norm(opt.centerCoherence-truth), norm(opt.centerBest-truth), ...
    polish.e0, polish.tStar, polish.tBest, polish.applied, polish.reason, ...
    polish.agreeFraction, polish.finalPeriodError_um, polish.bestMetric, polish.direction);
fprintf('DIAGNOSTIC %s SAMPLES t=%s signedErrors=%s zeroCrossings=%s\n', label, ...
    mat2str(polish.tList, 12), mat2str(polish.errorList, 12), mat2str(polish.zList, 12));
end

function [metric, nValid, rListOpt, err, analysis] = legacy_metric_local(data, center, cfg)
fitRange = cfg.centerOpt.fitRadiusRange;
if isempty(fitRange)
    fitRange = [cfg.design.R0-cfg.design.w/2, cfg.design.R0+cfg.design.w/2];
end
fitRange = sort(fitRange(:).');
rListOpt = max(cfg.radius.rMin, fitRange(1)):cfg.centerOpt.rStep:min(cfg.radius.rMax, fitRange(2));
if isempty(rListOpt); rListOpt = cfg.design.R0; end
lambdaDesign = design_period(rListOpt, cfg);
analysis = extract_inphase_duty_vs_radius(data, center, rListOpt, cfg);
valid = isfinite(analysis.periodMean) & isfinite(lambdaDesign);
valid = valid & analysis.nPeriods >= cfg.centerOpt.minNPeriods;
valid = valid & analysis.periodStd <= cfg.centerOpt.maxPeriodStd_um;
valid = valid & abs(analysis.periodMean-lambdaDesign) <= cfg.centerOpt.maxAbsPeriodError_um;
nValid = nnz(valid);
err = analysis.periodMean(valid)-lambdaDesign(valid);
metric = Inf;
if nValid < cfg.centerOpt.minValidRadii; return; end
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
end

function value = max_absolute_local(values)
values = values(isfinite(values));
value = NaN;
if ~isempty(values); value = max(abs(values)); end
end

function failures = objective_checks_local()
failures = 0;
try
    [X, Y] = meshgrid(linspace(0, 20, 80));
    center = [-20, 11];
    N = 2*pi*30/3;
    I = cos(N*atan2(Y-center(2), X-center(1)));
    [J, info] = center_stripe_coherence(center, X, Y, I, N, [25, 40], 0.5, 20);
    Jshift = center_stripe_coherence(center, X, Y, 4*I+17, N, [25, 40], 0.5, 20);
    failures = failures + check_local(isfinite(J) && J > 0.5 && J <= 1+1e-12, ...
        sprintf('objective normalized harmonic J=%.12f expected (0.5,1]', J));
    failures = failures + check_local(abs(J-Jshift) < 1e-12, ...
        sprintf('objective offset/scale invariance J=%.12f transformed=%.12f', J, Jshift));
    Jcolumn = center_stripe_coherence(center(:), X(:), Y(:), I(:), N, [25, 40], 0.5, 20);
    failures = failures + check_local(abs(J-Jcolumn) < 1e-12, ...
        sprintf('objective row/column consistency matrix=%.12f column=%.12f', J, Jcolumn));
    [Jempty, emptyInfo] = center_stripe_coherence(center, [], [], [], N, [25, 40], 0.5, 20);
    [Jnan, nanInfo] = center_stripe_coherence(center, X, Y, NaN(size(I)), N, [25, 40], 0.5, 20);
    Jconstant = center_stripe_coherence(center, X, Y, ones(size(I)), N, [25, 40], 0.5, 20);
    Jfew = center_stripe_coherence(center, X, Y, I, N, [25, 40], 0.5, numel(I)+1);
    failures = failures + check_local(Jempty == 0 && emptyInfo.nPixels == 0, ...
        sprintf('objective empty J=%g nPixels=%d expected 0,0', Jempty, emptyInfo.nPixels));
    failures = failures + check_local(Jnan == 0 && nanInfo.nPixels == 0, ...
        sprintf('objective all-NaN J=%g nPixels=%d expected 0,0', Jnan, nanInfo.nPixels));
    failures = failures + check_local(Jconstant == 0 && Jfew == 0, ...
        sprintf('objective constant J=%g and insufficient pixels J=%g expected 0,0', Jconstant, Jfew));
    failures = failures + check_local(all(isfield(info, {'nPixels','phase','thetaRef'})), ...
        sprintf('objective required info fields, nPixels=%d phase=%.8f thetaRef=%.8f', ...
        info.nPixels, info.phase, info.thetaRef));
catch exception
    failures = failures + 1;
    fprintf('FAIL objective edge cases: %s\n%s\n', exception.message, ...
        getReport(exception, 'extended', 'hyperlinks', 'off'));
end
end

function failures = polish_checks_local()
failures = 0;
try
    cfg = synthetic_cfg_local(30, 3);
    [X, Y] = meshgrid(linspace(0, 20, 128));
    data = struct('X', X, 'Y', Y, 'inphase', NaN(size(X)));
    initial = [-20, 10];
    cfg.centerOpt.radialPolish.range_um = 0.10;
    [center, info] = polish_center_radial_period(data, initial(:), cfg);
    failures = failures + check_local(isequal(center(:).', initial) && info.noValidCandidate && ...
        isinf(info.bestMetric) && ~info.applied && strcmp(info.reason, 'too few valid samples') && ...
        all(isnan(info.errorList)) && all(isnan(info.zList)) && ~isempty(info.bestAnalysisOnOptGrid), ...
        sprintf('polish all-NaN center=[%.8f %.8f] noValid=%d applied=%d reason=%s metric=%g finiteSamples=%d/%d', ...
        center, info.noValidCandidate, info.applied, info.reason, info.bestMetric, ...
        nnz(isfinite(info.errorList)), numel(info.tList)));
catch exception
    failures = failures + 1;
    fprintf('FAIL polish all-NaN: %s\n%s\n', exception.message, ...
        getReport(exception, 'extended', 'hyperlinks', 'off'));
end
try
    cfg = synthetic_cfg_local(30, 3);
    [X, Y] = meshgrid(linspace(0, 20, 128));
    initial = [-20, 10];
    data = struct('X', X, 'Y', Y, ...
        'inphase', cos(2*pi*30/3*atan2(Y-initial(2), X-initial(1))+0.37));
    disabledCfg = cfg;
    disabledCfg.centerOpt.radialPolish.enable = false;
    [center, info] = polish_center_radial_period(data, initial(:), disabledCfg);
    [metric, nValid, ~, errors, expectedAnalysis] = legacy_metric_local(data, initial, cfg);
    expectedMedian = NaN;
    if nValid >= cfg.centerOpt.minValidRadii; expectedMedian = median(errors); end
    failures = failures + check_local(isequal(center, initial) && ~info.enabled && ...
        ~info.applied && info.tBest == 0 && strcmp(info.reason, 'disabled') && ...
        isempty(info.tList) && isempty(info.errorList) && isempty(info.zList), ...
        sprintf('polish disabled no sampling: center=[%.8f %.8f] enabled=%d applied=%d reason=%s sampleCount=%d', ...
        center, info.enabled, info.applied, info.reason, numel(info.tList)));
    failures = failures + check_local(nValid >= cfg.centerOpt.minValidRadii && ...
        ~info.noValidCandidate && same_numbers_local(info.bestMetric, metric, 1e-12) && ...
        same_numbers_local(info.finalPeriodError_um, expectedMedian, 1e-12) && ...
        isequaln(info.bestAnalysisOnOptGrid.periodMean, expectedAnalysis.periodMean), ...
        sprintf('polish disabled valid final evaluation: median=%+.12g expected=%+.12g metric=%.12g expected=%.12g validRadii=%d', ...
        info.finalPeriodError_um, expectedMedian, info.bestMetric, metric, nValid));

    zeroCfg = cfg;
    zeroCfg.centerOpt.radialPolish.range_um = 0;
    [center, info] = polish_center_radial_period(data, initial, zeroCfg);
    failures = failures + check_local(isequal(center, initial) && ~info.applied && info.tBest == 0 && ...
        numel(info.tList) == 1 && info.tList(1) == 0 && ...
        strcmp(info.reason, 'too few valid samples') && ~info.noValidCandidate && ...
        same_numbers_local(info.errorList, expectedMedian, 1e-12) && ...
        same_numbers_local(info.finalPeriodError_um, expectedMedian, 1e-12), ...
        sprintf('polish one sample retains center and valid analysis: samples=%d minSamples=%d reason=%s median=%+.12g', ...
        numel(info.tList), cfg.centerOpt.radialPolish.minSamples, info.reason, info.finalPeriodError_um));

    sampledCfg = cfg;
    sampledCfg.centerOpt.radialPolish.range_um = 0.10;
    sampledCfg.centerOpt.radialPolish.step_um = 0.05;
    sampleCenter = initial+[0.18, -0.03];
    [center, info] = polish_center_radial_period(data, sampleCenter, sampledCfg);
    expectedErrors = nan(size(info.tList));
    for it = 1:numel(info.tList)
        [~, count, ~, errors] = legacy_metric_local(data, sampleCenter+info.tList(it)*info.direction, sampledCfg);
        if count >= sampledCfg.centerOpt.minValidRadii; expectedErrors(it) = median(errors); end
    end
    slope = cfg.design.periodRef.LambdaRef/cfg.design.periodRef.Rref;
    expectedZ = info.tList-expectedErrors/slope;
    finite = isfinite(expectedZ);
    failures = failures + check_local(same_numbers_local(info.errorList, expectedErrors, 1e-12) && ...
        same_numbers_local(info.zList, expectedZ, 1e-12) && info.slope == slope, ...
        sprintf('polish independent signed samples and zero-crossing formula: finite=%d/%d slope=%.12g errors=%s z=%s', ...
        nnz(finite), numel(info.tList), slope, mat2str(info.errorList, 12), mat2str(info.zList, 12)));
    if nnz(finite) >= sampledCfg.centerOpt.radialPolish.minSamples
        expectedStar = median(expectedZ(finite));
        expectedAgree = nnz(abs(expectedZ(finite)-expectedStar) <= sampledCfg.centerOpt.radialPolish.agreeTolerance_um)/numel(info.tList);
        expectedApplied = expectedAgree >= sampledCfg.centerOpt.radialPolish.minAgreeFraction && ...
            abs(expectedStar) <= sampledCfg.centerOpt.radialPolish.range_um;
        expectedBest = 0;
        if expectedApplied; expectedBest = expectedStar; end
        failures = failures + check_local(same_numbers_local(info.tStar, expectedStar, 1e-12) && ...
            same_numbers_local(info.agreeFraction, expectedAgree, 1e-12) && ...
            info.applied == expectedApplied && same_numbers_local(info.tBest, expectedBest, 1e-12) && ...
            same_numbers_local(center, sampleCenter+expectedBest*info.direction, 1e-12), ...
            sprintf('polish median estimate and total-grid agreement denominator: tStar=%+.12g expected=%+.12g agree=%.12g expected=%.12g finite=%d denominator=%d applied=%d', ...
            info.tStar, expectedStar, info.agreeFraction, expectedAgree, nnz(finite), numel(info.tList), info.applied));
    else
        failures = failures + check_local(~info.applied && isnan(info.tStar) && ...
            strcmp(info.reason, 'too few valid samples') && isequal(center, sampleCenter), ...
            sprintf('polish finite sample requirement: finite=%d minSamples=%d applied=%d reason=%s', ...
            nnz(finite), sampledCfg.centerOpt.radialPolish.minSamples, info.applied, info.reason));
    end
    [metric, nValid, ~, errors, expectedAnalysis] = legacy_metric_local(data, center, sampledCfg);
    expectedMedian = NaN;
    if nValid >= sampledCfg.centerOpt.minValidRadii; expectedMedian = median(errors); end
    failures = failures + check_local(same_numbers_local(info.bestMetric, metric, 1e-12) && ...
        same_numbers_local(info.finalPeriodError_um, expectedMedian, 1e-12) && ...
        isequaln(info.bestAnalysisOnOptGrid.periodMean, expectedAnalysis.periodMean), ...
        sprintf('polish final analysis independently matches applied center: median=%+.12g expected=%+.12g metric=%.12g expected=%.12g', ...
        info.finalPeriodError_um, expectedMedian, info.bestMetric, metric));
catch exception
    failures = failures + 1;
    fprintf('FAIL polish signed-error edge cases: %s\n%s\n', exception.message, ...
        getReport(exception, 'extended', 'hyperlinks', 'off'));
end
failures = failures + qc_checks_local();
end

function failures = qc_checks_local()
failures = 0;
try
    cfg = synthetic_cfg_local(30, 3);
    cfg.centerOpt.radialPolish.enable = false;
    cfg.centerOpt.coherence.localRange_um = 0;
    cfg.centerOpt.coherence.fineRange_um = 0;
    [X, Y] = meshgrid(linspace(0, 20, 128));
    center = [-20, 10];
    data = struct('X', X, 'Y', Y, ...
        'inphase', cos(2*pi*30/3*atan2(Y-center(2), X-center(1))+0.37));
    opt = optimize_center_by_inphase_coherence(data, center, cfg);
    failures = failures + check_local(~opt.qc.flag && ~opt.polish.applied && ...
        any(contains(string(opt.qc.notes), 'disabled')) && isempty(opt.qc.reasons) && ...
        opt.qc.finalCoherence == opt.finalJ && ...
        same_numbers_local(opt.qc.finalPeriodError_um, opt.polish.finalPeriodError_um, 1e-12) && ...
        ~opt.qc.polishApplied, ...
        sprintf('QC disabled polish is informational with valid final signal: flag=%d J=%.12g median=%+.12g reasons=%s notes=%s', ...
        opt.qc.flag, opt.finalJ, opt.polish.finalPeriodError_um, ...
        char(reasons_text_local(opt.qc.reasons)), char(reasons_text_local(opt.qc.notes))));
    data.inphase(:) = NaN;
    opt = optimize_center_by_inphase_coherence(data, center, cfg);
    failures = failures + check_local(opt.qc.flag && opt.polish.noValidCandidate && ...
        ~isfinite(opt.qc.finalPeriodError_um) && opt.qc.finalCoherence == 0 && ...
        ~isempty(opt.qc.reasons) && any(contains(string(opt.qc.notes), 'disabled')), ...
        sprintf('QC invalid final signal is flagged while disabled remains a note: flag=%d J=%.12g median=%g reasons=%s notes=%s', ...
        opt.qc.flag, opt.qc.finalCoherence, opt.qc.finalPeriodError_um, ...
        char(reasons_text_local(opt.qc.reasons)), char(reasons_text_local(opt.qc.notes))));
catch exception
    failures = failures + 1;
    fprintf('FAIL QC edge cases: %s\n%s\n', exception.message, ...
        getReport(exception, 'extended', 'hyperlinks', 'off'));
end
end

function same = same_numbers_local(actual, expected, tolerance)
same = isequal(size(actual), size(expected));
if ~same; return; end
finite = isfinite(actual) & isfinite(expected);
same = all(abs(actual(finite)-expected(finite)) <= tolerance) && ...
    isequaln(actual(~finite), expected(~finite));
end

function failed = check_local(condition, message)
failed = ~logical(condition);
if failed; status = 'FAIL'; else; status = 'PASS'; end
fprintf('%s %s\n', status, message);
end

function value = reasons_text_local(reasons)
if isempty(reasons); value = ""; else; value = strjoin(string(reasons(:).'), '; '); end
end
