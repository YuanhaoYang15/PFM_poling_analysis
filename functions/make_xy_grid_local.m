function [X, Y] = make_xy_grid_local(Xraw, Yraw, phaseSize, cfg)
%MAKE_XY_GRID_LOCAL Build X/Y matrices for a phase matrix.

ny = phaseSize(1);
nx = phaseSize(2);

if isempty(Xraw)
    if isfield(cfg, 'preprocess') && ~isempty(cfg.preprocess.scanSizeUm)
        x = linspace(0, cfg.preprocess.scanSizeUm(1), nx);
    else
        x = (0:nx-1) * cfg.preprocess.pixelSizeUm;
    end
else
    x = Xraw;
end

if isempty(Yraw)
    if isfield(cfg, 'preprocess') && ~isempty(cfg.preprocess.scanSizeUm)
        y = linspace(0, cfg.preprocess.scanSizeUm(2), ny);
    else
        y = (0:ny-1) * cfg.preprocess.pixelSizeUm;
    end
else
    y = Yraw;
end

if ismatrix(x) && all(size(x) == phaseSize)
    X = x;
else
    x = x(:).';
    if numel(x) ~= nx
        x = linspace(min(x), max(x), nx);
    end
    X = repmat(x, ny, 1);
end

if ismatrix(y) && all(size(y) == phaseSize)
    Y = y;
else
    y = y(:);
    if numel(y) ~= ny
        y = linspace(min(y), max(y), ny).';
    end
    Y = repmat(y, 1, nx);
end

end
