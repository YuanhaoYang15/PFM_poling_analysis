function ff = afm_farfield_mask(prof, uMat, cfg)
%AFM_FARFIELD_MASK Build structure masks from a cross-waveguide profile.
%
% The ridge edges are the mid-level crossings of the profile. From each
% edge the profile is searched outward for the local floor minimum (moat).
% The far field starts cfg.farFieldMargin_um beyond each moat minimum; the
% far-field regions are used for the linear plane correction.
%
% Output:
%   ff.mask / leftMask / rightMask : 2-D far-field masks
%   ff.moatLeftMask2D / rightMask2D : 2-D moat band masks
%   ff.topMask1D / leftMoatMask1D / rightMoatMask1D : profile masks
%   ff.uMoatLeft_um / uMoatRight_um
%   ff.leftClipped / rightClipped : search window hit the image edge

if nargin < 3 || isempty(cfg)
    cfg = struct();
end
moatSearch_um = getfield_or(cfg, 'moatSearch_um', 0.6);
margin_um = getfield_or(cfg, 'farFieldMargin_um', 0.1);
edgeFraction = getfield_or(cfg, 'edgeLevelFraction', 0.5);
moatWindow_um = getfield_or(cfg, 'moatWindow_um', 0.05);

coord = prof.coord_um(:).';
vals = prof.values_nm(:).';
n = numel(vals);

ff = struct();
ff.uMatSize = size(uMat);
ff.leftMask = false(size(uMat));
ff.rightMask = false(size(uMat));
ff.mask = false(size(uMat));
ff.moatLeftMask2D = false(size(uMat));
ff.moatRightMask2D = false(size(uMat));
ff.leftMoatMask1D = false(1, n);
ff.rightMoatMask1D = false(1, n);
ff.uMoatLeft_um = NaN;
ff.uMoatRight_um = NaN;
ff.uLeftEdge_um = NaN;
ff.uRightEdge_um = NaN;
ff.leftClipped = false;
ff.rightClipped = false;
ff.ok = false;

if n < 5 || all(~isfinite(vals))
    return;
end

[pk, ipk] = max(vals);
floorMin = min(vals);
if ~isfinite(pk) || ~isfinite(floorMin)
    return;
end
thr = pk - edgeFraction * (pk - floorMin);

leftCross = find(vals(1:ipk) < thr, 1, 'last');
rightCross = find(vals(ipk:end) < thr, 1, 'first') + ipk - 1;

dx = median(diff(coord));
searchPts = max(1, round(moatSearch_um / dx));
winPts = max(1, round(moatWindow_um / dx));

if ~isempty(leftCross)
    ff.uLeftEdge_um = coord(leftCross);
    a = max(1, leftCross - searchPts);
    b = leftCross;
    [~, im] = min(vals(a:b));
    im = a + im - 1;
    ff.uMoatLeft_um = coord(im);
    ff.leftClipped = (leftCross - searchPts) < 1;
    ma = max(a, im - winPts);
    mb = min(b, im + winPts);
    ff.leftMoatMask1D(ma:mb) = true;
    ff.moatLeftMask2D = uMat >= coord(ma) & uMat <= coord(mb);
    ff.leftMask = uMat < (ff.uMoatLeft_um - margin_um);
end

if ~isempty(rightCross)
    ff.uRightEdge_um = coord(rightCross);
    a = rightCross;
    b = min(n, rightCross + searchPts);
    [~, im] = min(vals(a:b));
    im = a + im - 1;
    ff.uMoatRight_um = coord(im);
    ff.rightClipped = (rightCross + searchPts) > n;
    ma = max(a, im - winPts);
    mb = min(b, im + winPts);
    ff.rightMoatMask1D(ma:mb) = true;
    ff.moatRightMask2D = uMat >= coord(ma) & uMat <= coord(mb);
    ff.rightMask = uMat > (ff.uMoatRight_um + margin_um);
end

ff.mask = ff.leftMask | ff.rightMask;
ff.ok = any(ff.mask(:));

end
