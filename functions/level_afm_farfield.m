function [Zf, level] = level_afm_farfield(Z, X, Y, mask, cfg)
%LEVEL_AFM_FARFIELD Remove a linear plane fitted to the far-field regions.
%
% The plane z = a*x + b*y + c is fitted only on the far-field pixels, so the
% ridge and trenches do not bias the correction.

if nargin < 5 || isempty(cfg)
    cfg = struct();
end
order = getfield_or(cfg, 'order', 1);
if order ~= 1
    error('level_afm_farfield currently supports order = 1 only.');
end

mask = mask & isfinite(Z);

level = struct();
level.ok = false;
level.flag = "ok";
level.order = order;
level.maskCount = nnz(mask);
level.residualRms_nm = NaN;
level.residualStd_nm = NaN;
level.coef = [];

if nnz(mask) < 50
    Zf = Z;
    level.flag = "insufficient_farfield";
    return;
end

A = [X(mask), Y(mask), ones(nnz(mask), 1)];
coef = A \ Z(mask);
Afull = [X(:), Y(:), ones(numel(Z), 1)];
Zf = Z - reshape(Afull * coef, size(Z));

res = Z(mask) - A * coef;
level.ok = true;
level.coef = coef;
level.residualRms_nm = sqrt(mean(res.^2));
level.residualStd_nm = std(res);

end
