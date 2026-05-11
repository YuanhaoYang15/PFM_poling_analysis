function [X, Y, Z] = scattered_to_grid_local(x, y, z)
%SCATTERED_TO_GRID_LOCAL Convert scattered/grid xyz columns to matrices.

xu = unique(x(isfinite(x)));
yu = unique(y(isfinite(y)));

[X, Y] = meshgrid(xu, yu);
Z = nan(size(X));

[~, ix] = ismember(x, xu);
[~, iy] = ismember(y, yu);

valid = ix > 0 & iy > 0 & isfinite(z);
ind = sub2ind(size(Z), iy(valid), ix(valid));
Z(ind) = z(valid);

end
