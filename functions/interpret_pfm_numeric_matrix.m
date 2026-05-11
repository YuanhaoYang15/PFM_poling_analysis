function [X, Y, phase, info] = interpret_pfm_numeric_matrix(M, cfg)
%INTERPRET_PFM_NUMERIC_MATRIX Interpret raw numeric PFM matrix.
%
% Output:
%   X, Y    coordinate matrices in um
%   phase   phase matrix
%   info    detected format information

M = remove_empty_nan_borders(M);

info = struct();
info.originalSize = size(M);

% Case 1: scattered [x, y, phase]
if size(M,2) == 3 && looks_like_scattered_xyz(M)
    x = M(:,1);
    y = M(:,2);
    z = M(:,3);

    valid = isfinite(x) & isfinite(y) & isfinite(z);
    x = x(valid); y = y(valid); z = z(valid);

    [X, Y, phase] = scattered_to_grid_local(x, y, z);
    [X, Y, info.coordScale] = scale_coordinates_to_um(X, Y, cfg);
    info.format = 'scattered_xyz';
    return;
end

% Case 2: first row/column are axes
if cfg.preprocess.detectAxisInMatrix && size(M,1) > 5 && size(M,2) > 5
    [ok, X, Y, phase] = try_axis_embedded_matrix(M);
    if ok
        [X, Y, info.coordScale] = scale_coordinates_to_um(X, Y, cfg);
        info.format = 'axis_embedded_matrix';
        return;
    end
end

% Case 3: phase matrix only
phase = M;
[ny, nx] = size(phase);

if ~isempty(cfg.preprocess.scanSizeUm)
    x = linspace(0, cfg.preprocess.scanSizeUm(1), nx);
    y = linspace(0, cfg.preprocess.scanSizeUm(2), ny);
else
    x = (0:nx-1) * cfg.preprocess.pixelSizeUm;
    y = (0:ny-1) * cfg.preprocess.pixelSizeUm;
end

[X, Y] = meshgrid(x, y);
[X, Y, info.coordScale] = scale_coordinates_to_um(X, Y, cfg);
info.format = 'phase_matrix_only';

end

function tf = looks_like_scattered_xyz(M)
    x = M(:,1); y = M(:,2); z = M(:,3);
    valid = isfinite(x) & isfinite(y) & isfinite(z);
    x = x(valid); y = y(valid);

    if numel(x) < 20
        tf = false;
        return;
    end

    nx = numel(unique(x));
    ny = numel(unique(y));

    % For scattered/grid xyz exports, x and y should repeat.
    tf = nx > 2 && ny > 2 && nx*ny >= 0.3*numel(x);
end

function [ok, X, Y, Z] = try_axis_embedded_matrix(M)
    ok = false; X = []; Y = []; Z = [];

    firstRow = M(1, 2:end);
    firstCol = M(2:end, 1);

    if nnz(isfinite(firstRow)) < 3 || nnz(isfinite(firstCol)) < 3
        return;
    end

    rowValid = firstRow(isfinite(firstRow));
    colValid = firstCol(isfinite(firstCol));

    isRowAxis = is_mostly_monotonic(rowValid);
    isColAxis = is_mostly_monotonic(colValid);

    if ~(isRowAxis && isColAxis)
        return;
    end

    Zcand = M(2:end, 2:end);

    % Reject if the remaining matrix is mostly NaN.
    if nnz(isfinite(Zcand)) < 0.5*numel(Zcand)
        return;
    end

    x = firstRow;
    y = firstCol;

    % Fill missing axis values if needed.
    if any(~isfinite(x))
        idx = find(isfinite(x));
        x = interp1(idx, x(idx), 1:numel(x), 'linear', 'extrap');
    end
    if any(~isfinite(y))
        idx = find(isfinite(y));
        y = interp1(idx, y(idx), 1:numel(y), 'linear', 'extrap');
    end

    [X, Y] = meshgrid(x, y);
    Z = Zcand;
    ok = true;
end

function tf = is_mostly_monotonic(v)
    if numel(v) < 3
        tf = false;
        return;
    end
    d = diff(v);
    d = d(isfinite(d) & d ~= 0);
    if isempty(d)
        tf = false;
        return;
    end
    tf = mean(d > 0) > 0.8 || mean(d < 0) > 0.8;
end


function [X, Y, scaleInfo] = scale_coordinates_to_um(X, Y, cfg)
    scaleInfo = struct();
    scaleInfo.mode = 'none';
    scaleInfo.factor = 1;

    coordUnit = 'um';
    if isfield(cfg, 'preprocess') && isfield(cfg.preprocess, 'coordUnit')
        coordUnit = cfg.preprocess.coordUnit;
    end

    if strcmpi(coordUnit, 'nm')
        factor = 1e-3;
        mode = 'nm_to_um';
    elseif strcmpi(coordUnit, 'auto')
        xr = max(X(:), [], 'omitnan') - min(X(:), [], 'omitnan');
        yr = max(Y(:), [], 'omitnan') - min(Y(:), [], 'omitnan');

        % PFM images in this project are typically tens of microns.
        % If the coordinate range is hundreds/thousands, it is very likely nm.
        if max(xr, yr) > 200
            factor = 1e-3;
            mode = 'auto_nm_to_um';
        else
            factor = 1;
            mode = 'auto_keep_um';
        end
    else
        factor = 1;
        mode = 'keep_um';
    end

    X = X * factor;
    Y = Y * factor;

    scaleInfo.mode = mode;
    scaleInfo.factor = factor;
end
