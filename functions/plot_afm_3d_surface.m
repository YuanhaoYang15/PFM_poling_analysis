function figPath = plot_afm_3d_surface(result, afmCfg, figPath, exaggeration)
%PLOT_AFM_3D_SURFACE 3-D surface reconstruction of the leveled height.
%
% The height is drawn in um with a configurable vertical exaggeration and
% simple lighting. Output is a standalone PNG next to the per-scan summary.
% Pass exaggeration = 1 for a true-scale reconstruction.

if nargin < 3 || isempty(figPath)
    figPath = fullfile(afmCfg.paths.afmFigureRoot, ...
        sprintf('%s_3d.png', result.rawName));
end
if nargin < 4 || isempty(exaggeration)
    E = getfield_or(afmCfg.plot, 'verticalExaggeration', 8);
else
    E = exaggeration;
end

X = result.data.X;
Y = result.data.Y;
Z = result.data.heightLevel;

ds = getfield_or(afmCfg.plot, 'surfaceDownsample', 2);
if ds > 1
    X = X(1:ds:end, 1:ds:end);
    Y = Y(1:ds:end, 1:ds:end);
    Z = Z(1:ds:end, 1:ds:end);
end
resolution = getfield_or(afmCfg.plot, 'resolution', 300);

fig = figure('Color', 'w', 'Visible', 'off', 'WindowStyle', 'normal');
set(fig, 'Units', 'pixels', 'Position', [50, 40, 1100, 850]);

try
    ax = axes(fig);
    Ztrue_um = Z / 1000;
    surf(ax, X, Y, Ztrue_um, Ztrue_um, 'EdgeColor', 'none');
    shading(ax, 'interp');
    colormap(ax, parula);
    cb = colorbar(ax);
    cb.Label.String = 'height (\mum)';
    xlabel(ax, 'x (\mum)');
    ylabel(ax, 'y (\mum)');
    zlabel(ax, 'height (\mum)');
    axis(ax, 'tight');
    grid(ax, 'on');
    box(ax, 'on');

    % Follow the true data proportions instead of stretching the z axis to
    % fill the axes; E = 1 is a true-scale reconstruction.
    xRange = max(X(:)) - min(X(:));
    yRange = max(Y(:)) - min(Y(:));
    zRange = max(Ztrue_um(:)) - min(Ztrue_um(:));
    refRange = max([xRange, yRange, eps]);
    pbaspect(ax, [xRange, yRange, E * zRange] / refRange);

    view(ax, -37.5, 30);
    camlight(ax, 'headlight');
    lighting(ax, 'gouraud');

    if E == 1
        scaleText = 'true scale';
    else
        scaleText = sprintf('vertical exaggeration x%g', E);
    end
    titleText = sprintf('%s | 3-D reconstruction | %s leveled | %s', ...
        result.rawName, getfield_or(afmCfg.afm.level, 'method', 'farfield_plane'), ...
        scaleText);
    if isfield(result, 'sidewall') && isfinite(result.sidewall.leftMean_deg)
        titleText = sprintf('%s | sidewall L/R = %.0f/%.0f deg', ...
            titleText, result.sidewall.leftMean_deg, result.sidewall.rightMean_deg);
    end
    title(ax, titleText, 'Interpreter', 'none', 'FontWeight', 'bold');

    exportgraphics(fig, figPath, 'Resolution', resolution);
    close(fig);
catch ME
    if isgraphics(fig)
        close(fig);
    end
    rethrow(ME);
end

end
