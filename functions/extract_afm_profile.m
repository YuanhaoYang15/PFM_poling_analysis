function prof = extract_afm_profile(Z, X, Y, angle_deg, cfg)
%EXTRACT_AFM_PROFILE Median profile perpendicular to the waveguide.
%
% angle_deg is the waveguide direction (deg from the x axis). The
% perpendicular coordinate is u = x*cos(a) + y*sin(a); image pixels are
% binned in u and the profile is the median per bin.

if nargin < 5 || isempty(cfg)
    cfg = struct();
end
nBins = getfield_or(cfg, 'bins', []);
if isempty(nBins) || ~isfinite(nBins) || nBins < 16
    nBins = max(size(Z));
end

u = X * cosd(angle_deg) + Y * sind(angle_deg);
mask = isfinite(Z);
uu = u(mask);
zz = Z(mask);

edges = linspace(min(uu), max(uu), nBins + 1);
idx = discretize(uu, edges);
vals = accumarray(idx, zz, [nBins, 1], @median, NaN);
centers = (edges(1:end-1) + edges(2:end)) / 2;

prof = struct();
prof.angle_deg = angle_deg;
prof.coord_um = centers(:).';
prof.values_nm = vals(:).';
prof.uRange_um = [min(uu), max(uu)];
prof.nBins = nBins;

end
