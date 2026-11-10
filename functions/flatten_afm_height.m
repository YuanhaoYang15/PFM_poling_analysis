function [Zf, info] = flatten_afm_height(Z, cfg)
%FLATTEN_AFM_HEIGHT Level an AFM height image.
%
% Methods:
%   none       : no leveling
%   plane      : remove a global first-order plane
%   line       : remove a first-order line fit from every row
%   plane_line : plane first, then per-row line (default)
%   poly       : remove a 2-D polynomial of order cfg.polyOrder
%
% NaN pixels are preserved and excluded from every fit.

if nargin < 2 || isempty(cfg)
    cfg = struct();
end

method = getfield_or(cfg, 'method', 'plane_line');
polyOrder = getfield_or(cfg, 'polyOrder', 2);

info = struct();
info.method = method;
info.rmsBefore_nm = roughness_rms(Z);
info.rmsAfter_nm = NaN;

switch lower(method)
    case 'none'
        Zf = Z;

    case 'plane'
        Zf = remove_global_plane(Z);

    case 'line'
        Zf = remove_line_by_line(Z);

    case 'plane_line'
        Zf = remove_line_by_line(remove_global_plane(Z));

    case 'poly'
        Zf = remove_2d_poly(Z, polyOrder);

    otherwise
        error('Unknown AFM flatten method: %s', method);
end

info.rmsAfter_nm = roughness_rms(Zf);

end

function Zf = remove_global_plane(Z)
    [ny, nx] = size(Z);
    [X, Y] = meshgrid(1:nx, 1:ny);
    A = [X(:), Y(:), ones(numel(Z), 1)];
    mask = isfinite(Z);

    if nnz(mask) < 10
        Zf = Z;
        return;
    end

    coef = A(mask, :) \ Z(mask);
    Zf = Z - reshape(A * coef, [ny, nx]);
end

function Zf = remove_line_by_line(Z)
    [ny, nx] = size(Z);
    x = (1:nx).';
    A = [x, ones(nx, 1)];
    Zf = Z;

    for r = 1:ny
        row = Z(r, :).';
        mask = isfinite(row);
        if nnz(mask) < 3
            continue;
        end
        coef = A(mask, :) \ row(mask);
        Zf(r, :) = (row - A * coef).';
    end
end

function Zf = remove_2d_poly(Z, order)
    [ny, nx] = size(Z);
    [X, Y] = meshgrid(1:nx, 1:ny);
    xn = (X - mean(X(:))) / max(std(X(:)), eps);
    yn = (Y - mean(Y(:))) / max(std(Y(:)), eps);

    terms = [];
    for p = 0:order
        for q = 0:(order - p)
            terms(:, end + 1) = xn(:).^p .* yn(:).^q; %#ok<AGROW>
        end
    end

    mask = isfinite(Z);
    if nnz(mask) < size(terms, 2) + 1
        Zf = Z;
        return;
    end

    coef = terms(mask, :) \ Z(mask);
    Zf = Z - reshape(terms * coef, [ny, nx]);
end

function value = roughness_rms(Z)
    z = Z(isfinite(Z));
    if isempty(z)
        value = NaN;
    else
        value = sqrt(mean((z - mean(z)).^2));
    end
end
