function sw = extract_afm_sidewall(Z, X, Y, uMat, prof, step, ff, cfg)
%EXTRACT_AFM_SIDEWALL Ridge sidewall angles from the leveled profile.
%
% The sidewall angle is measured between lowFraction and highFraction of the
% local step height (moat level to ridge top), fitted on the median profile
% and per slice on a rotated resampling. The angle is relative to the
% horizontal; AFM tip convolution rounds the top corner, so the 10-90%
% range is used.
%
% Output:
%   sw.left_deg / right_deg         : median-profile sidewall angles
%   sw.leftRun_um / rightRun_um     : lateral run of the 10-90% segment
%   sw.leftFit / rightFit           : fit details (u10/u90, slope, intercept,
%                                     zFloor/zTop, floor u)
%   sw.leftSlices_deg / rightSlices_deg : per-slice angle samples
%   sw.sliceV_um                    : slice positions along the waveguide
%   sw.leftMean_deg / leftStd_deg / leftP10_deg / leftP90_deg (same for right)
%   sw.topWidth_um / baseWidth_um

if nargin < 8 || isempty(cfg)
    cfg = struct();
end
lowFrac = getfield_or(cfg, 'lowFraction', 0.10);
highFrac = getfield_or(cfg, 'highFraction', 0.90);
nSlices = getfield_or(cfg, 'nSlices', 120);

coord = prof.coord_um(:).';
vals = prof.values_nm(:).';
zTop = step.topLevel_nm;

sw = struct('left_deg', NaN, 'right_deg', NaN, ...
    'leftRun_um', NaN, 'rightRun_um', NaN, ...
    'leftFit', empty_fit(), 'rightFit', empty_fit(), ...
    'leftSlices_deg', [], 'rightSlices_deg', [], 'sliceV_um', [], ...
    'leftMean_deg', NaN, 'leftStd_deg', NaN, ...
    'leftP10_deg', NaN, 'leftP90_deg', NaN, ...
    'rightMean_deg', NaN, 'rightStd_deg', NaN, ...
    'rightP10_deg', NaN, 'rightP90_deg', NaN, ...
    'topWidth_um', NaN, 'baseWidth_um', NaN, ...
    'lowFraction', lowFrac, 'highFraction', highFrac);

if ~isfinite(zTop)
    return;
end

idxTop = find(step.topMask1D);
if isempty(idxTop)
    return;
end
uTopL = coord(idxTop(1));
uTopR = coord(idxTop(end));

sw.leftFit = sidewall_one(coord, vals, ff.uMoatLeft_um, uTopL, ...
    step.moatLeft_nm, zTop, lowFrac, highFrac);
sw.rightFit = sidewall_one(coord, vals, ff.uMoatRight_um, uTopR, ...
    step.moatRight_nm, zTop, lowFrac, highFrac);
sw.left_deg = sw.leftFit.angle_deg;
sw.right_deg = sw.rightFit.angle_deg;
sw.leftRun_um = sw.leftFit.run_um;
sw.rightRun_um = sw.rightFit.run_um;

sw.topWidth_um = uTopR - uTopL;
if isfinite(ff.uMoatLeft_um) && isfinite(ff.uMoatRight_um)
    sw.baseWidth_um = ff.uMoatRight_um - ff.uMoatLeft_um;
end

% Per-slice angles on a rotated resampling.
vMat = -X * sind(prof.angle_deg) + Y * cosd(prof.angle_deg);
uGrid = linspace(prctile(uMat(:), 0.1), prctile(uMat(:), 99.9), 400);
vGrid = linspace(prctile(vMat(:), 1), prctile(vMat(:), 99), nSlices);
[UG, VG] = meshgrid(uGrid, vGrid);
a = prof.angle_deg;
XG = UG * cosd(a) - VG * sind(a);
YG = UG * sind(a) + VG * cosd(a);
ZR = interp2(X, Y, Z, XG, YG, 'linear');

leftSlices = nan(numel(vGrid), 1);
rightSlices = nan(numel(vGrid), 1);
for k = 1:numel(vGrid)
    fitL = sidewall_one(uGrid, ZR(k, :), ff.uMoatLeft_um, uTopL, ...
        step.moatLeft_nm, zTop, lowFrac, highFrac);
    fitR = sidewall_one(uGrid, ZR(k, :), ff.uMoatRight_um, uTopR, ...
        step.moatRight_nm, zTop, lowFrac, highFrac);
    leftSlices(k) = fitL.angle_deg;
    rightSlices(k) = fitR.angle_deg;
end
sw.leftSlices_deg = leftSlices;
sw.rightSlices_deg = rightSlices;
sw.sliceV_um = vGrid(:);

[sw.leftMean_deg, sw.leftStd_deg, sw.leftP10_deg, sw.leftP90_deg] = ...
    slice_stats(leftSlices);
[sw.rightMean_deg, sw.rightStd_deg, sw.rightP10_deg, sw.rightP90_deg] = ...
    slice_stats(rightSlices);

end

function fit = sidewall_one(coord, vals, uOuter, uInner, zFloor, zTop, lowFrac, highFrac)
    fit = empty_fit();
    fit.zFloor = zFloor;
    fit.zTop = zTop;
    fit.uFloor = uOuter;

    if ~isfinite(uOuter) || ~isfinite(uInner) || ~isfinite(zFloor) || ~isfinite(zTop)
        return;
    end
    H = zTop - zFloor;
    if H <= 0
        return;
    end

    reg = coord >= min(uOuter, uInner) & coord <= max(uOuter, uInner) & isfinite(vals);
    uc = coord(reg);
    zc = vals(reg);
    if numel(uc) < 4
        return;
    end

    if uOuter > uInner
        [uc, order] = sort(uc, 'descend');
    else
        [uc, order] = sort(uc, 'ascend');
    end
    zc = zc(order);

    i10 = find(zc >= zFloor + lowFrac * H, 1, 'first');
    i90 = find(zc <= zFloor + highFrac * H, 1, 'last');
    if isempty(i10) || isempty(i90) || i90 <= i10
        return;
    end

    p = polyfit(uc(i10:i90), zc(i10:i90), 1);
    fit.angle_deg = atand(abs(p(1)) / 1000);   % slope nm/um -> ratio
    fit.run_um = abs(uc(i90) - uc(i10));
    fit.slope_nm_per_um = p(1);
    fit.intercept_nm = p(2);
    fit.u10 = uc(i10);
    fit.u90 = uc(i90);
    fit.z10 = zc(i10);
    fit.z90 = zc(i90);
    fit.highLevel_nm = zFloor + highFrac * H;
    fit.lowLevel_nm = zFloor + lowFrac * H;
    fit.ok = true;
end

function fit = empty_fit()
    fit = struct('ok', false, 'angle_deg', NaN, 'run_um', NaN, ...
        'slope_nm_per_um', NaN, 'intercept_nm', NaN, ...
        'u10', NaN, 'u90', NaN, 'z10', NaN, 'z90', NaN, ...
        'lowLevel_nm', NaN, 'highLevel_nm', NaN, ...
        'zFloor', NaN, 'zTop', NaN, 'uFloor', NaN);
end

function [m, s, p10, p90] = slice_stats(samples)
    v = samples(isfinite(samples));
    if isempty(v)
        m = NaN; s = NaN; p10 = NaN; p90 = NaN;
    else
        m = mean(v);
        s = std(v);
        p10 = prctile(v, 10);
        p90 = prctile(v, 90);
    end
end
