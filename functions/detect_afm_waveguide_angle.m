function orient = detect_afm_waveguide_angle(Z, X, Y, cfg)
%DETECT_AFM_WAVEGUIDE_ANGLE Estimate the waveguide direction from the image.
%
% Edges along the waveguide produce gradients perpendicular to it, so the
% dominant gradient orientation gives the waveguide axis. A weighted
% circular histogram of gradient orientations is built over the strongest
% gradient pixels; the peak and its circular mean give the angle.
%
% Output:
%   orient.waveguideAngle_deg : waveguide axis, deg from the x axis (mod 180)
%   orient.angle_deg          : slice direction (perpendicular to waveguide)
%                               used as u = x*cosd(a) + y*sind(a)
%   orient.peakWeight         : peak share of the orientation histogram
%   orient.histogram / binCenters_deg

if nargin < 4 || isempty(cfg)
    cfg = struct();
end

override_deg = getfield_or(cfg, 'override_deg', []);
percentile = getfield_or(cfg, 'gradientPercentile', 90);
smoothBins = getfield_or(cfg, 'smoothBins', 5);
peakWindow_deg = getfield_or(cfg, 'peakWindow_deg', 5);

if ~isempty(override_deg) && isfinite(override_deg)
    orient = make_orient(override_deg, NaN, NaN, [], []);
    orient.override = true;
    return;
end

dx = median(diff(X(1, :)));
dy = median(diff(Y(:, 1)));
[gx, gy] = gradient(Z, dx, dy);
mag = hypot(gx, gy);
finiteMag = mag(isfinite(mag));

if isempty(finiteMag) || max(finiteMag) <= 0
    orient = make_orient(NaN, NaN, NaN, [], []);
    orient.ok = false;
    return;
end

thr = prctile(finiteMag, percentile);
sel = isfinite(Z) & mag > thr;
phi = atan2d(gy(sel), gx(sel));
edgeDir = mod(phi - 90, 180);
w = mag(sel);

nBins = 180;
binIdx = min(nBins, floor(edgeDir) + 1);
h = accumarray(binIdx, w, [nBins, 1]);
h = [h; h; h];
h = movmean(h, smoothBins);
hc = h(nBins + 1:2 * nBins);
[peakVal, ipk] = max(hc);

centers = (0.5:1:179.5).';
d = mod(centers - centers(ipk) + 90, 180) - 90;
near = abs(d) <= peakWindow_deg;
edgeDirFine = mod(atan2d(sum(hc(near) .* sind(2 * centers(near))), ...
    sum(hc(near) .* cosd(2 * centers(near)))) / 2, 180);

orient = make_orient(edgeDirFine, peakVal / sum(hc), thr, hc, centers);
orient.ok = isfinite(orient.angle_deg);

end

function orient = make_orient(edgeDir_deg, peakWeight, thr, hist, centers)
    sliceAngle = mod(edgeDir_deg - 90, 180);
    if sliceAngle > 90
        sliceAngle = sliceAngle - 180;
    end

    orient = struct();
    orient.waveguideAngle_deg = edgeDir_deg;
    orient.angle_deg = sliceAngle;
    orient.peakWeight = peakWeight;
    orient.gradientThreshold = thr;
    orient.histogram = hist;
    orient.binCenters_deg = centers;
    orient.override = false;
    orient.ok = isfinite(sliceAngle);
end
