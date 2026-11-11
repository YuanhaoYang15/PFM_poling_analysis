function [center, info] = find_center_by_stripe_coherence(data, cfg, startCenter)
%FIND_CENTER_BY_STRIPE_COHERENCE Deterministic global and local stripe search.

startTime = tic;
if nargin < 3; startCenter = []; end
cfg = set_default_batch_options(cfg);
settings = cfg.centerOpt.coherence;
if isempty(settings.radiusRange)
    settings.radiusRange = [cfg.radius.rMin, cfg.radius.rMax];
end
settings.radiusRange = sort(settings.radiusRange(:).');
validate_settings_local(settings);
if ~isequal(size(data.X), size(data.Y), size(data.inphase)) || ...
        ~ismatrix(data.inphase) || isempty(data.inphase)
    error('find_center_by_stripe_coherence:InvalidImage', 'Nonempty X, Y and inphase matrices must have the same size.');
end
if ~isempty(startCenter) && (numel(startCenter) ~= 2 || any(~isfinite(startCenter(:))))
    error('find_center_by_stripe_coherence:InvalidCenter', 'startCenter must be empty or contain two finite coordinates.');
end
N = 2*pi * cfg.design.periodRef.Rref / cfg.design.periodRef.LambdaRef;
R0 = cfg.design.R0;
if ~isscalar(R0) || ~isfinite(R0) || R0 <= 0 || ~isscalar(N) || ~isfinite(N) || N <= 0
    error('find_center_by_stripe_coherence:InvalidDesign', 'R0 and the design angular harmonic must be positive and finite.');
end

coordinateMask = isfinite(data.X) & isfinite(data.Y);
if ~any(coordinateMask(:))
    error('find_center_by_stripe_coherence:InvalidCoordinates', 'The image has no finite coordinates.');
end
xAll = data.X(coordinateMask);
yAll = data.Y(coordinateMask);
xBounds = [min(xAll), max(xAll)];
yBounds = [min(yAll), max(yAll)];
p0 = [mean(xBounds), mean(yBounds)];
if isempty(settings.globalDistanceHalfRange_um)
    settings.globalDistanceHalfRange_um = hypot(diff(xBounds), diff(yBounds)) / 2;
end

finitePixel = coordinateMask & isfinite(data.inphase);
x = double(data.X(finitePixel));
y = double(data.Y(finitePixel));
value = double(data.inphase(finitePixel));
x = x(:); y = y(:); value = value(:);
nEval = 0;
usedGlobal = isempty(startCenter);
peakRatio = NaN;
globalBest = [];
globalJ = NaN;
globalCandidateCount = 0;

if isempty(value) || all(value == value(1))
    if usedGlobal
        globalBest = p0 + [max(0, R0 - settings.globalDistanceHalfRange_um), 0];
        center = globalBest;
        globalJ = 0;
        settings.localRange_um = 3.0;
    else
        center = double(startCenter(:).');
    end
    [J, objectiveInfo] = center_stripe_coherence(center, x, y, value, ...
        N, settings.radiusRange, settings.taper_um, settings.minPixels);
    info = struct('J', J, 'nEval', 1, 'usedGlobal', usedGlobal, ...
        'peakRatio', peakRatio, 'globalBest', globalBest, 'globalJ', globalJ, ...
        'globalCandidateCount', 0, 'hitWindowEdge', false, 'coarsePassCount', 0, ...
        'simplexExitflag', 0, 'settings', settings, 'nPixels', objectiveInfo.nPixels, ...
        'phase', objectiveInfo.phase, 'thetaRef', objectiveInfo.thetaRef, 'time_s', toc(startTime));
    return;
end

if usedGlobal
    [xGlobal, yGlobal, valueGlobal] = block_average_local( ...
        data.X, data.Y, data.inphase, settings.globalDecimate);
    minPixelsGlobal = max(1, ceil(settings.minPixels / settings.globalDecimate^2));
    distanceList = max(0, R0 - settings.globalDistanceHalfRange_um): ...
        settings.globalDistanceStep_um:(R0 + settings.globalDistanceHalfRange_um);
    nAngles = max(1, ceil(2*pi*R0 / settings.globalTangentialStep_um));
    angleList = (0:nAngles-1) * (2*pi/nAngles);
    globalScores = zeros(numel(distanceList), nAngles);
    for ia = 1:nAngles
        direction = [cos(angleList(ia)), sin(angleList(ia))];
        for id = 1:numel(distanceList)
            candidate = p0 + distanceList(id) * direction;
            globalScores(id, ia) = center_stripe_coherence_prepared_local(candidate, ...
                xGlobal, yGlobal, valueGlobal, N, settings.radiusRange, ...
                settings.taper_um, minPixelsGlobal);
        end
    end
    globalCandidateCount = numel(globalScores);
    nEval = nEval + globalCandidateCount;
    [globalJ, bestIndex] = max(globalScores(:));
    [bestDistanceIndex, bestAngleIndex] = ind2sub(size(globalScores), bestIndex);
    globalBest = p0 + distanceList(bestDistanceIndex) * ...
        [cos(angleList(bestAngleIndex)), sin(angleList(bestAngleIndex))];
    angularDifference = abs(angle(exp(1i * (angleList - angleList(bestAngleIndex)))));
    nearAngle = R0 * angularDifference <= 7;
    nearDistance = abs(distanceList(:) - distanceList(bestDistanceIndex)) <= 4;
    outside = ~(nearDistance & nearAngle);
    if any(outside(:))
        secondJ = max(globalScores(outside));
    else
        secondJ = 0;
    end
    peakRatio = globalJ / secondJ;
    center = globalBest;
    settings.localRange_um = 3.0;
else
    center = double(startCenter(:).');
end

coarseOffsets = offsets_local(settings.localRange_um, settings.coarseStep_um);
hitWindowEdge = false;
coarsePassCount = 0;
for ipass = 1:4
    coarsePassCount = ipass;
    [center, ~, ix, iy] = search_grid_local(center, coarseOffsets, @evaluate_local);
    hitWindowEdge = numel(coarseOffsets) > 1 && ...
        (ix == 1 || ix == numel(coarseOffsets) || iy == 1 || iy == numel(coarseOffsets));
    if ~hitWindowEdge
        break;
    end
end

fineOffsets = offsets_local(settings.fineRange_um, settings.fineStep_um);
[center, bestJ] = search_grid_local(center, fineOffsets, @evaluate_local);
options = optimset('Display', 'off', 'TolX', 1e-3, 'TolFun', 1e-8);
[simplexCenter, negativeJ, exitflag] = fminsearch(@negative_objective_local, center, options);
if all(isfinite(simplexCenter)) && isfinite(negativeJ) && -negativeJ > bestJ
    center = simplexCenter(:).';
end
[finalJ, objectiveInfo] = center_stripe_coherence(center, x, y, value, ...
    N, settings.radiusRange, settings.taper_um, settings.minPixels);
nEval = nEval + 1;
info = struct();
info.J = finalJ;
info.nEval = nEval;
info.usedGlobal = usedGlobal;
info.peakRatio = peakRatio;
info.globalBest = globalBest;
info.globalJ = globalJ;
info.globalCandidateCount = globalCandidateCount;
info.hitWindowEdge = logical(hitWindowEdge);
info.coarsePassCount = coarsePassCount;
info.simplexExitflag = exitflag;
info.settings = settings;
info.nPixels = objectiveInfo.nPixels;
info.phase = objectiveInfo.phase;
info.thetaRef = objectiveInfo.thetaRef;
info.time_s = toc(startTime);

    function J = evaluate_local(candidate)
        J = center_stripe_coherence_prepared_local(candidate, x, y, value, N, ...
            settings.radiusRange, settings.taper_um, settings.minPixels);
        nEval = nEval + 1;
    end

    function valueNegative = negative_objective_local(candidate)
        valueNegative = -evaluate_local(candidate);
    end
end

function [center, bestJ, bestX, bestY] = search_grid_local(anchor, offsets, objective)
center = anchor;
bestJ = -Inf;
bestDistance = Inf;
bestX = 1;
bestY = 1;
for iy = 1:numel(offsets)
    for ix = 1:numel(offsets)
        candidate = anchor + [offsets(ix), offsets(iy)];
        J = objective(candidate);
        distance = hypot(offsets(ix), offsets(iy));
        if J > bestJ || (J == bestJ && distance < bestDistance)
            bestJ = J;
            center = candidate;
            bestDistance = distance;
            bestX = ix;
            bestY = iy;
        end
    end
end
end

function offsets = offsets_local(halfRange, step)
offsets = unique([-halfRange:step:halfRange, -halfRange, 0, halfRange]);
end

function [x, y, value] = block_average_local(X, Y, I, factor)
[ny, nx] = size(I);
outSize = [ceil(ny/factor), ceil(nx/factor)];
sumX = zeros(outSize);
sumY = zeros(outSize);
sumI = zeros(outSize);
count = zeros(outSize);
for iy = 1:min(factor, ny)
    rows = iy:factor:ny;
    outRows = 1:numel(rows);
    for ix = 1:min(factor, nx)
        cols = ix:factor:nx;
        outCols = 1:numel(cols);
        xPart = double(X(rows, cols));
        yPart = double(Y(rows, cols));
        valuePart = double(I(rows, cols));
        valid = isfinite(xPart) & isfinite(yPart) & isfinite(valuePart);
        xPart(~valid) = 0;
        yPart(~valid) = 0;
        valuePart(~valid) = 0;
        sumX(outRows, outCols) = sumX(outRows, outCols) + xPart;
        sumY(outRows, outCols) = sumY(outRows, outCols) + yPart;
        sumI(outRows, outCols) = sumI(outRows, outCols) + valuePart;
        count(outRows, outCols) = count(outRows, outCols) + valid;
    end
end
valid = count > 0;
x = sumX(valid) ./ count(valid);
y = sumY(valid) ./ count(valid);
value = sumI(valid) ./ count(valid);
x = x(:); y = y(:); value = value(:);
end

function validate_settings_local(settings)
positiveFields = {'taper_um', 'coarseStep_um', 'fineStep_um', ...
    'globalDistanceStep_um', 'globalTangentialStep_um'};
for ii = 1:numel(positiveFields)
    value = settings.(positiveFields{ii});
    if ~isscalar(value) || ~isfinite(value) || value <= 0
        error('find_center_by_stripe_coherence:InvalidSettings', '%s must be positive and finite.', positiveFields{ii});
    end
end
nonnegativeFields = {'minPixels', 'localRange_um', 'fineRange_um'};
for ii = 1:numel(nonnegativeFields)
    value = settings.(nonnegativeFields{ii});
    if ~isscalar(value) || ~isfinite(value) || value < 0
        error('find_center_by_stripe_coherence:InvalidSettings', '%s must be nonnegative and finite.', nonnegativeFields{ii});
    end
end
if numel(settings.radiusRange) ~= 2 || any(~isfinite(settings.radiusRange)) || ...
        ~isscalar(settings.globalDecimate) || ~isfinite(settings.globalDecimate) || ...
        settings.globalDecimate < 1 || settings.globalDecimate ~= floor(settings.globalDecimate)
    error('find_center_by_stripe_coherence:InvalidSettings', 'Invalid radius range or global decimation factor.');
end
halfRange = settings.globalDistanceHalfRange_um;
if ~isempty(halfRange) && (~isscalar(halfRange) || ~isfinite(halfRange) || halfRange < 0)
    error('find_center_by_stripe_coherence:InvalidSettings', 'globalDistanceHalfRange_um must be empty or nonnegative and finite.');
end
end

function J = center_stripe_coherence_prepared_local(center, x, y, value, N, rRange, taper_um, minPixels)
% Search inputs have already been validated and reduced to finite double columns.
J = 0;
dx = x - center(1);
dy = y - center(2);
r = hypot(dx, dy);
w = min(1, max(0, min(r - rRange(1), rRange(2) - r) / taper_um + 0.5));
mask = w > 0;
nPixels = nnz(mask);
if nPixels == 0 || nPixels < minPixels
    return;
end

dx = dx(mask);
dy = dy(mask);
w = w(mask);
value = value(mask);
thetaRef = atan2(mean(y(mask)) - center(2), mean(x(mask)) - center(1));
if all(value == value(1))
    return;
end
theta = angle(complex(dx, dy) * exp(-1i * thetaRef));
sumW = sum(w);
v = value - sum(w .* value) / sumW;
z = sum(w .* v .* exp(-1i * N * theta));
denominator = sqrt(sumW * sum(w .* v.^2));
if denominator > 0 && isfinite(denominator) && isfinite(z)
    J = abs(z) / denominator;
end
end
