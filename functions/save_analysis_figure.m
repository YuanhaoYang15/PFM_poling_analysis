function save_analysis_figure(fig, pngPath, cfg)
%SAVE_ANALYSIS_FIGURE Save PNG and FIG robustly.
%
% If a figure is created with Visible='off', savefig() preserves that
% invisible state. This helper temporarily makes the figure visible before
% saving the .fig, then restores/closes according to cfg.plot options.

if nargin < 3
    cfg = struct();
end

if isempty(fig) || ~isvalid(fig)
    warning('save_analysis_figure:InvalidFigure', 'Invalid figure handle. Skipped.');
    return;
end

[figFolder, name, ~] = fileparts(pngPath);
if ~exist(figFolder, 'dir')
    mkdir(figFolder);
end

figPath = fullfile(figFolder, [name, '.fig']);

resolution = 300;
if isfield(cfg, 'plot') && isfield(cfg.plot, 'resolution') && ~isempty(cfg.plot.resolution)
    resolution = cfg.plot.resolution;
end

savePng = true;
if isfield(cfg, 'plot') && isfield(cfg.plot, 'saveFigures')
    savePng = cfg.plot.saveFigures;
end

if savePng
    exportgraphics(fig, pngPath, 'Resolution', resolution);
end

oldVisible = get(fig, 'Visible');
oldWindowStyle = get(fig, 'WindowStyle');

set(fig, 'Visible', 'on');

if isfield(cfg, 'plot') && isfield(cfg.plot, 'figureWindowStyle') && ~isempty(cfg.plot.figureWindowStyle)
    try
        set(fig, 'WindowStyle', cfg.plot.figureWindowStyle);
    catch
    end
end

savefig(fig, figPath);

try
    set(fig, 'Visible', oldVisible);
catch
end
try
    set(fig, 'WindowStyle', oldWindowStyle);
catch
end

closeAfterSave = false;
if isfield(cfg, 'plot') && isfield(cfg.plot, 'closeAfterSave')
    closeAfterSave = cfg.plot.closeAfterSave;
end

if closeAfterSave && isvalid(fig)
    close(fig);
end

end
