function h = shade_radius_region(x1, x2, yRange, cfg)
%SHADE_RADIUS_REGION Add vertical shaded region to current axes.

yl = yRange;
xPatch = [x1, x2, x2, x1];
yPatch = [yl(1), yl(1), yl(2), yl(2)];

h = patch(xPatch, yPatch, cfg.plot.wgShadeColor, ...
    'FaceAlpha', cfg.plot.wgShadeAlpha, ...
    'EdgeColor', 'none');

uistack(h, 'bottom');

end
