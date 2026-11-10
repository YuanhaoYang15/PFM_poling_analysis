function step = extract_afm_step(Z, X, Y, uMat, prof, ff, cfg)
%EXTRACT_AFM_STEP Measure the ridge top to far-field and moat step heights.
%
% The ridge top plateau and edges come from the leveled cross-waveguide
% profile. Far-field levels come from ff.leftMask / ff.rightMask, moat
% levels from ff.moatLeftMask2D / ff.moatRightMask2D. The primary etch
% depth is top minus far field; top minus moat is reported separately.

if nargin < 7 || isempty(cfg)
    cfg = struct();
end
topTol = getfield_or(cfg, 'topTolerance_nm', 20);
topFlatSlope = getfield_or(cfg, 'topFlatSlope_nm_per_um', 50);
minTopWidth_um = getfield_or(cfg, 'minTopWidth_um', 0.05);
edgeFraction = getfield_or(cfg, 'edgeLevelFraction', 0.5);
usePlane = getfield_or(cfg, 'leveling', true);
minRidgeWidth_um = getfield_or(cfg, 'minRidgeWidth_um', 0.2);

coord = prof.coord_um(:).';
vals = prof.values_nm(:).';
n = numel(vals);

step = init_step(coord, vals, prof.angle_deg);

if n < 5 || all(~isfinite(vals))
    step.flag = "empty_profile";
    return;
end

[pk, ipk] = max(vals);
floorMin = min(vals);
if ~isfinite(pk) || ~isfinite(floorMin)
    step.flag = "empty_profile";
    return;
end

% Ridge-top plateau: contiguous region around the peak within topTol
% (fallback), and the flattest contiguous segment around the peak.
inBand = vals >= pk - topTol;
li0 = ipk;
while li0 > 1 && inBand(li0 - 1)
    li0 = li0 - 1;
end
ri0 = ipk;
while ri0 < n && inBand(ri0 + 1)
    ri0 = ri0 + 1;
end
tolMask1D = false(1, n);
tolMask1D(li0:ri0) = true;

slope = local_slope(coord, vals);
flatMask1D = false(1, n);
a = ipk;
while a > 1 && abs(slope(a - 1)) <= topFlatSlope
    a = a - 1;
end
b = ipk;
while b < n && abs(slope(b + 1)) <= topFlatSlope
    b = b + 1;
end
flatMask1D(a:b) = true;
if (coord(b) - coord(a)) < minTopWidth_um
    flatMask1D = tolMask1D;
    a = li0;
    b = ri0;
end

step.topMask1D = flatMask1D;
step.topFlatSlope_nm_per_um = topFlatSlope;
step.topLevel1D_nm = median(vals(step.topMask1D), 'omitnan');

topMask2D = uMat >= coord(a) & uMat <= coord(b);
[step.topLevel_nm, step.topRq_nm, step.topRa_nm] = ...
    roi_level(Z, X, Y, topMask2D, usePlane);
step.topMask2D = topMask2D;

% Ridge edges and width from the mid-level crossings.
thr = pk - edgeFraction * (pk - floorMin);
leftCross = find(vals(1:ipk) < thr, 1, 'last');
rightCross = find(vals(ipk:end) < thr, 1, 'first') + ipk - 1;

if isempty(leftCross) || isempty(rightCross)
    step.flag = append_flag(step.flag, "open_profile");
end
if ~isempty(leftCross)
    step.leftEdge_um = coord(leftCross);
end
if ~isempty(rightCross)
    step.rightEdge_um = coord(rightCross);
end
if ~isempty(leftCross) && ~isempty(rightCross)
    step.ridgeWidth_um = coord(rightCross) - coord(leftCross);
    if step.ridgeWidth_um < minRidgeWidth_um
        step.flag = append_flag(step.flag, "narrow_ridge");
    end
end

% Far-field and moat levels.
if any(ff.leftMask(:))
    step.farLeft_nm = median(Z(ff.leftMask), 'omitnan');
end
if any(ff.rightMask(:))
    step.farRight_nm = median(Z(ff.rightMask), 'omitnan');
end
if any(ff.moatLeftMask2D(:))
    step.moatLeft_nm = median(Z(ff.moatLeftMask2D), 'omitnan');
end
if any(ff.moatRightMask2D(:))
    step.moatRight_nm = median(Z(ff.moatRightMask2D), 'omitnan');
end

% Primary steps: ridge top to far field.
if isfinite(step.topLevel_nm) && isfinite(step.farLeft_nm)
    step.stepLeft_nm = step.topLevel_nm - step.farLeft_nm;
end
if isfinite(step.topLevel_nm) && isfinite(step.farRight_nm)
    step.stepRight_nm = step.topLevel_nm - step.farRight_nm;
end
% Secondary steps: ridge top to moat bottom.
if isfinite(step.topLevel_nm) && isfinite(step.moatLeft_nm)
    step.stepMoatLeft_nm = step.topLevel_nm - step.moatLeft_nm;
end
if isfinite(step.topLevel_nm) && isfinite(step.moatRight_nm)
    step.stepMoatRight_nm = step.topLevel_nm - step.moatRight_nm;
end

stepValues = [step.stepLeft_nm, step.stepRight_nm];
if all(isfinite(stepValues))
    step.stepMean_nm = mean(stepValues);
    step.asymmetry_nm = step.stepLeft_nm - step.stepRight_nm;
elseif any(isfinite(stepValues))
    step.stepMean_nm = mean(stepValues(isfinite(stepValues)));
end

if ff.leftClipped
    step.flag = append_flag(step.flag, "left_floor_clipped");
end
if ff.rightClipped
    step.flag = append_flag(step.flag, "right_floor_clipped");
end
if ~any(ff.mask(:))
    step.flag = append_flag(step.flag, "no_farfield");
end

step.levelMode = ternary(usePlane, 'roi_plane', 'roi_median');
step.ok = all(isfinite([step.topLevel_nm, step.farLeft_nm, step.farRight_nm]));
if strlength(step.flag) == 0
    if step.ok
        step.flag = "ok";
    else
        step.flag = "incomplete";
    end
end

end

function step = init_step(coord, vals, angle_deg)
    n = numel(vals);
    step = struct();
    step.angle_deg = angle_deg;
    step.coord_um = coord;
    step.values_nm = vals;
    step.levelMode = '';
    step.topFlatSlope_nm_per_um = NaN;
    step.topMask1D = false(1, n);
    step.topMask2D = false(0, 0);
    step.topLevel1D_nm = NaN;
    step.topLevel_nm = NaN;
    step.farLeft_nm = NaN;
    step.farRight_nm = NaN;
    step.moatLeft_nm = NaN;
    step.moatRight_nm = NaN;
    step.stepLeft_nm = NaN;
    step.stepRight_nm = NaN;
    step.stepMean_nm = NaN;
    step.asymmetry_nm = NaN;
    step.stepMoatLeft_nm = NaN;
    step.stepMoatRight_nm = NaN;
    step.topRq_nm = NaN;
    step.topRa_nm = NaN;
    step.leftEdge_um = NaN;
    step.rightEdge_um = NaN;
    step.ridgeWidth_um = NaN;
    step.ok = false;
    step.flag = "";
end

function [level, rq, ra] = roi_level(Z, X, Y, mask, usePlane)
    z = Z(mask);
    z = z(isfinite(z));
    level = NaN;
    rq = NaN;
    ra = NaN;

    if isempty(z)
        return;
    end

    if usePlane && numel(z) >= 10
        xs = X(mask);
        ys = Y(mask);
        A = [xs(:), ys(:), ones(numel(xs), 1)];
        coef = A \ z(:);
        level = [mean(xs(:)), mean(ys(:)), 1] * coef;
        res = z(:) - A * coef;
        rq = sqrt(mean(res.^2));
        ra = mean(abs(res - mean(res)));
    else
        level = median(z);
        rq = std(z);
        ra = mean(abs(z - mean(z)));
    end
end

function out = ternary(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end

function flag = append_flag(flag, newFlag)
    if strlength(flag) == 0
        flag = newFlag;
    else
        flag = strjoin([flag, newFlag], "+");
    end
end

function s = local_slope(coord, vals)
    n = numel(vals);
    s = zeros(1, n);
    if n < 2
        return;
    end
    s(1) = (vals(2) - vals(1)) / (coord(2) - coord(1));
    s(n) = (vals(n) - vals(n - 1)) / (coord(n) - coord(n - 1));
    if n > 2
        s(2:n-1) = (vals(3:n) - vals(1:n-2)) ./ (coord(3:n) - coord(1:n-2));
    end
end
