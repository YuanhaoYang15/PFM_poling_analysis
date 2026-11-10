function paths = plot_afm_sidewall_qc(result, afmCfg, outputRoot)
%PLOT_AFM_SIDEWALL_QC Two illustration figures for the sidewall angle.
%
%   1. <rawName>_sidewall_definition.png : leveled cross-waveguide profile
%      with the 10-90% fitted segments, horizontal references, angle arcs
%      and step-height annotation.
%   2. <rawName>_sidewall_vs_slice.png : left/right sidewall angle for every
%      slice along the waveguide, showing the uniformity.

if nargin < 3 || isempty(outputRoot)
    outputRoot = afmCfg.paths.afmFigureRoot;
end
if ~exist(outputRoot, 'dir')
    mkdir(outputRoot);
end
resolution = getfield_or(afmCfg.plot, 'resolution', 300);

prof = result.profile;
sw = result.sidewall;
step = result.step;

colorLeft = [0.10, 0.55, 0.90];
colorRight = [0.10, 0.75, 0.40];
colorTop = [0.90, 0.55, 0.10];
colorMoat = [0.55, 0.55, 0.55];

paths = struct();
paths.definition = fullfile(outputRoot, ...
    sprintf('%s_sidewall_definition.png', result.rawName));
paths.vsSlice = fullfile(outputRoot, ...
    sprintf('%s_sidewall_vs_slice.png', result.rawName));

%% ---- Figure 1: angle definition ----
fig = figure('Color', 'w', 'Visible', 'off', 'WindowStyle', 'normal');
set(fig, 'Units', 'pixels', 'Position', [40, 40, 1500, 620]);
try
    layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    % Panel A: full profile with levels and fitted segments.
    axA = nexttile(layout);
    plot(axA, prof.coord_um, prof.values_nm, '-', ...
        'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.2);
    hold(axA, 'on');
    draw_level_line(axA, step.topLevel_nm, colorTop);
    draw_level_line(axA, step.moatLeft_nm, colorMoat);
    draw_level_line(axA, step.moatRight_nm, colorMoat);
    draw_fit_segment(axA, sw.leftFit, colorLeft);
    draw_fit_segment(axA, sw.rightFit, colorRight);
    xlabel(axA, 'u, perpendicular to waveguide (\mum)');
    ylabel(axA, 'height (nm)');
    title(axA, 'full cross-waveguide profile | colored: 10-90% fit segment', ...
        'Interpreter', 'none');
    grid(axA, 'on');

    % Panel B: zoom with the angle definition.
    axB = nexttile(layout);
    plot(axB, prof.coord_um, prof.values_nm, '-', ...
        'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.2);
    hold(axB, 'on');
    draw_level_line(axB, step.topLevel_nm, colorTop);
    draw_level_line(axB, step.moatLeft_nm, colorMoat);
    draw_level_line(axB, step.moatRight_nm, colorMoat);
    draw_fit_line(axB, sw.leftFit, colorLeft);
    draw_fit_line(axB, sw.rightFit, colorRight);
    if isfinite(sw.leftFit.uFloor) && isfinite(sw.rightFit.uFloor)
        pad = 0.25;
        xlim(axB, [sw.leftFit.uFloor - pad, sw.rightFit.uFloor + pad]);
    end
    annotate_side(axB, sw.leftFit, colorLeft, +1);
    annotate_side(axB, sw.rightFit, colorRight, -1);
    xlabel(axB, 'u, perpendicular to waveguide (\mum)');
    ylabel(axB, 'height (nm)');
    title(axB, sprintf(['sidewall angle = slope of the 10-90%% segment | ' ...
        'left %.1f deg, right %.1f deg'], sw.left_deg, sw.right_deg), ...
        'Interpreter', 'none');
    grid(axB, 'on');

    title(layout, sprintf(['%s | sidewall angle definition | %s leveled | ' ...
        'step height from moat to ridge top'], result.rawName, ...
        getfield_or(afmCfg.afm.level, 'method', 'farfield_plane')), ...
        'Interpreter', 'none', 'FontWeight', 'bold');

    export_png(fig, paths.definition, resolution);
    close(fig);
catch ME
    if isgraphics(fig)
        close(fig);
    end
    rethrow(ME);
end

%% ---- Figure 2: angle versus slice position ----
v = sw.sliceV_um(:);
vRel = v - mean(v, 'omitnan');
leftDeg = sw.leftSlices_deg(:);
rightDeg = sw.rightSlices_deg(:);

fig2 = figure('Color', 'w', 'Visible', 'off', 'WindowStyle', 'normal');
set(fig2, 'Units', 'pixels', 'Position', [40, 40, 1150, 620]);
try
    ax = axes(fig2);
    hold(ax, 'on');
    draw_std_band(ax, vRel, leftDeg, colorLeft);
    draw_std_band(ax, vRel, rightDeg, colorRight);
    plot(ax, vRel, leftDeg, 'o-', 'Color', colorLeft, ...
        'MarkerSize', 3, 'MarkerFaceColor', colorLeft, 'LineWidth', 1.0);
    plot(ax, vRel, rightDeg, 's-', 'Color', colorRight, ...
        'MarkerSize', 3, 'MarkerFaceColor', colorRight, 'LineWidth', 1.0);
    draw_mean_line(ax, vRel, leftDeg, colorLeft);
    draw_mean_line(ax, vRel, rightDeg, colorRight);
    xlabel(ax, 'position along waveguide, v (\mum)');
    ylabel(ax, 'sidewall angle (deg)');
    title(ax, sprintf(['%s | sidewall angle per slice | ' ...
        'left %.2f \\pm %.2f deg, right %.2f \\pm %.2f deg'], ...
        strrep(result.rawName, '_', '\_'), sw.leftMean_deg, sw.leftStd_deg, ...
        sw.rightMean_deg, sw.rightStd_deg), 'Interpreter', 'tex');
    legend(ax, {'left \pm1\sigma band', 'right \pm1\sigma band', ...
        'left slice', 'right slice', 'left mean', 'right mean'}, ...
        'Location', 'best');
    grid(ax, 'on');
    box(ax, 'on');

    export_png(fig2, paths.vsSlice, resolution);
    close(fig2);
catch ME
    if isgraphics(fig2)
        close(fig2);
    end
    rethrow(ME);
end

end

function draw_level_line(ax, level_nm, color)
    if ~isfinite(level_nm)
        return;
    end
    yl = ylim(ax);
    plot(ax, xlim(ax), [level_nm, level_nm], '--', 'Color', color, ...
        'LineWidth', 1.0);
    ylim(ax, yl);
end

function draw_fit_segment(ax, fit, color)
    if ~fit.ok
        return;
    end
    u = [fit.u10, fit.u90];
    z = fit.slope_nm_per_um * u + fit.intercept_nm;
    plot(ax, u, z, '-', 'Color', color, 'LineWidth', 2.5);
end

function draw_fit_line(ax, fit, color)
    if ~fit.ok
        return;
    end
    du = 0.06;
    u = [fit.u10 - du, fit.u90 + du];
    z = fit.slope_nm_per_um * u + fit.intercept_nm;
    plot(ax, u, z, ':', 'Color', color, 'LineWidth', 1.6);
    plot(ax, [fit.u10, fit.u90], [fit.z10, fit.z90], '-', ...
        'Color', color, 'LineWidth', 3.0);
    plot(ax, [fit.u10, fit.u90], [fit.z10, fit.z90], 'o', ...
        'Color', color, 'MarkerFaceColor', 'w', 'MarkerSize', 5);
end

function annotate_side(ax, fit, color, side)
    if ~fit.ok
        return;
    end
    % Horizontal reference at the low crossing.
    if side > 0
        uRef = [fit.u10, fit.u10 + 0.45];
    else
        uRef = [fit.u10 - 0.45, fit.u10];
    end
    plot(ax, uRef, [fit.z10, fit.z10], '-', 'Color', color, ...
        'LineWidth', 1.0);
    [pxPerU, pxPerZ] = axes_pixel_scale(ax);
    draw_angle_arc(ax, fit.u10, fit.z10, fit.angle_deg, side, color, ...
        pxPerU, pxPerZ);

    % Angle label at the arc midpoint.
    ru = 55 / pxPerU;
    rz = 55 / pxPerZ;
    th = deg2rad(fit.angle_deg / 2);
    if side > 0
        uTxt = fit.u10 + ru * cos(th);
    else
        uTxt = fit.u10 - ru * cos(th);
    end
    zTxt = fit.z10 + rz * sin(th);
    text(ax, uTxt, zTxt, sprintf('%.1f^\\circ', fit.angle_deg), ...
        'Color', color, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

    % Step-height marker on the floor side of the wall.
    uH = fit.uFloor;
    plot(ax, [uH, uH], [fit.zFloor, fit.zTop], '-', 'Color', [0.35, 0.35, 0.35], ...
        'LineWidth', 1.0);
    plot(ax, uH + [-0.03, 0.03], [fit.zFloor, fit.zFloor], '-', ...
        'Color', [0.35, 0.35, 0.35], 'LineWidth', 1.0);
    plot(ax, uH + [-0.03, 0.03], [fit.zTop, fit.zTop], '-', ...
        'Color', [0.35, 0.35, 0.35], 'LineWidth', 1.0);
    if side > 0
        text(ax, uH - 0.03, (fit.zFloor + fit.zTop) / 2, ...
            sprintf('H = %.0f nm', fit.zTop - fit.zFloor), ...
            'Color', [0.25, 0.25, 0.25], 'FontSize', 9, ...
            'HorizontalAlignment', 'right');
    else
        text(ax, uH + 0.03, (fit.zFloor + fit.zTop) / 2, ...
            sprintf('H = %.0f nm', fit.zTop - fit.zFloor), ...
            'Color', [0.25, 0.25, 0.25], 'FontSize', 9, ...
            'HorizontalAlignment', 'left');
    end
end

function draw_angle_arc(ax, u0, z0, angle_deg, side, color, pxPerU, pxPerZ)
    ru = 38 / pxPerU;
    rz = 38 / pxPerZ;
    th = deg2rad(linspace(0, angle_deg, 40));
    if side > 0
        uu = u0 + ru * cos(th);
    else
        uu = u0 - ru * cos(th);
    end
    zz = z0 + rz * sin(th);
    plot(ax, uu, zz, '-', 'Color', color, 'LineWidth', 1.2);
end

function [pxPerU, pxPerZ] = axes_pixel_scale(ax)
    fig = ancestor(ax, 'figure');
    figPos = get(fig, 'Position');
    axPos = get(ax, 'Position');
    xl = xlim(ax);
    yl = ylim(ax);
    pxPerU = max(axPos(3) * figPos(3) / (xl(2) - xl(1)), eps);
    pxPerZ = max(axPos(4) * figPos(4) / (yl(2) - yl(1)), eps);
end

function draw_mean_line(ax, v, values, color)
    m = mean(values, 'omitnan');
    if ~isfinite(m)
        return;
    end
    plot(ax, [min(v), max(v)], [m, m], '--', 'Color', color, 'LineWidth', 1.0);
end

function draw_std_band(ax, v, values, color)
    v = v(:);
    values = values(:);
    m = mean(values, 'omitnan');
    s = std(values, 'omitnan');
    if ~isfinite(m) || ~isfinite(s)
        return;
    end
    x = [min(v), max(v), max(v), min(v)];
    y = [m - s, m - s, m + s, m + s];
    patch(ax, x, y, color, 'FaceAlpha', 0.10, 'EdgeColor', 'none');
end

function export_png(fig, pathValue, resolution)
    if isfile(pathValue)
        try
            delete(pathValue);
        catch
        end
    end
    exportgraphics(fig, pathValue, 'Resolution', resolution);
end
