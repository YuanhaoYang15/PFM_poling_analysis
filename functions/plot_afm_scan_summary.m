function figPath = plot_afm_scan_summary(result, afmCfg, figPath)
%PLOT_AFM_SCAN_SUMMARY Per-scan AFM figure: raw height, far-field leveled
%height with detected masks, cross-waveguide profiles, and leveled histogram.

if nargin < 3 || isempty(figPath)
    figPath = fullfile(afmCfg.paths.afmFigureRoot, ...
        sprintf('%s_summary.png', result.rawName));
end

X = result.data.X;
Y = result.data.Y;
Zraw = result.data.heightRaw;
Zlev = result.data.heightLevel;
profRaw = result.profileRaw;
prof = result.profile;
ff = result.farfield;
step = result.step;

resolution = getfield_or(afmCfg.plot, 'resolution', 300);
colorTop = [0.90, 0.55, 0.10];
colorFar = [0.55, 0.55, 0.55];
colorLeft = [0.10, 0.55, 0.90];
colorRight = [0.10, 0.75, 0.40];

fig = figure('Color', 'w', 'Visible', 'off', 'WindowStyle', 'normal');
set(fig, 'Units', 'pixels', 'Position', [50, 40, 1380, 1000]);

try
    layout = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    ax1 = nexttile(layout);
    draw_height_axis(ax1, X, Y, Zraw, sprintf('%s | raw %s (nm)', ...
        result.rawName, result.heightField));

    ax2 = nexttile(layout);
    draw_height_axis(ax2, X, Y, Zlev, sprintf('%s | far-field leveled (waveguide %.1f deg, slice %.1f deg)', ...
        result.rawName, result.orientation.waveguideAngle_deg, ...
        result.orientation.angle_deg));
    hold(ax2, 'on');
    overlay_mask(ax2, X, Y, ff.mask, colorFar, 0.12);
    overlay_mask(ax2, X, Y, ff.moatLeftMask2D, colorLeft, 0.35);
    overlay_mask(ax2, X, Y, ff.moatRightMask2D, colorRight, 0.35);
    overlay_mask(ax2, X, Y, step.topMask2D, colorTop, 0.35);

    ax3 = nexttile(layout);
    plot(ax3, profRaw.coord_um, profRaw.values_nm, '--', ...
        'Color', [0.70, 0.70, 0.70], 'LineWidth', 0.9);
    hold(ax3, 'on');
    plot(ax3, prof.coord_um, prof.values_nm, '-', ...
        'Color', [0.00, 0.35, 0.70], 'LineWidth', 1.2);
    draw_level_line(ax3, step.topLevel_nm, colorTop);
    draw_level_line(ax3, step.farLeft_nm, colorFar);
    draw_level_line(ax3, step.farRight_nm, colorFar);
    draw_level_line(ax3, step.moatLeft_nm, colorLeft);
    draw_level_line(ax3, step.moatRight_nm, colorRight);
    xlabel(ax3, 'u, perpendicular to waveguide (\mum)');
    ylabel(ax3, 'height (nm)');
    title(ax3, sprintf(['cross-waveguide profile | etch L=%.0f, R=%.0f nm | ' ...
        'moat L=%.0f, R=%.0f nm'], step.stepLeft_nm, step.stepRight_nm, ...
        step.stepMoatLeft_nm, step.stepMoatRight_nm), 'Interpreter', 'none');
    legend(ax3, {'raw profile', 'far-field leveled', 'top level', ...
        'far field', 'far field', 'moat', 'moat'}, 'Location', 'best');
    grid(ax3, 'on');

    ax4 = nexttile(layout);
    z = Zlev(isfinite(Zlev));
    histogram(ax4, z, 80, 'FaceColor', [0.45, 0.45, 0.45], 'EdgeColor', 'none');
    hold(ax4, 'on');
    draw_level_line(ax4, step.topLevel_nm, colorTop);
    draw_level_line(ax4, step.farLeft_nm, colorFar);
    draw_level_line(ax4, step.moatLeft_nm, colorLeft);
    xlabel(ax4, 'height (nm)');
    ylabel(ax4, 'pixels');
    title(ax4, sprintf(['leveled histogram | Rq(top)=%.1f nm | farRms=%.1f nm | ' ...
        'width=%.2f um | rowJump=%d | stepFlag=%s'], step.topRq_nm, ...
        result.level.residualRms_nm, step.ridgeWidth_um, ...
        result.quality.rowJumpCount, step.flag), 'Interpreter', 'none');
    grid(ax4, 'on');

    exportgraphics(fig, figPath, 'Resolution', resolution);
    close(fig);
catch ME
    if isgraphics(fig)
        close(fig);
    end
    rethrow(ME);
end

end

function draw_height_axis(ax, X, Y, Z, titleText)
    imagesc(ax, X(1, :), Y(:, 1), Z);
    axis(ax, 'image');
    set(ax, 'YDir', 'normal', 'Box', 'on');
    colormap(ax, parula);
    cb = colorbar(ax);
    cb.Label.String = 'nm';
    xlabel(ax, 'x (\mum)');
    ylabel(ax, 'y (\mum)');
    title(ax, titleText, 'Interpreter', 'none', 'FontWeight', 'bold');
end

function overlay_mask(ax, X, Y, mask, color, alpha)
    if isempty(mask) || ~any(mask(:))
        return;
    end
    rgb = zeros([size(mask), 3]);
    for c = 1:3
        rgb(:, :, c) = color(c) * double(mask);
    end
    image(ax, X(1, :), Y(:, 1), rgb, 'AlphaData', alpha * double(mask));
end

function draw_level_line(ax, level_nm, color)
    if ~isfinite(level_nm)
        return;
    end
    yl = ylim(ax);
    plot(ax, xlim(ax), [level_nm, level_nm], '-', 'Color', color, 'LineWidth', 1.0);
    ylim(ax, yl);
end
