function cfg = set_default_batch_options(cfg)
%SET_DEFAULT_BATCH_OPTIONS Fill missing batch config fields with safe defaults.

if ~isfield(cfg, 'run'); cfg.run = struct(); end
cfg.run.skipExisting = get_nested_field(cfg, 'run.skipExisting', true);
cfg.run.forceReprocess = get_nested_field(cfg, 'run.forceReprocess', false);
cfg.run.regenerateFiguresForExisting = get_nested_field(cfg, 'run.regenerateFiguresForExisting', false);

if ~isfield(cfg, 'plot'); cfg.plot = struct(); end
cfg.plot.showFigures = get_nested_field(cfg, 'plot.showFigures', false);
cfg.plot.saveFigures = get_nested_field(cfg, 'plot.saveFigures', true);
cfg.plot.closeAfterSave = get_nested_field(cfg, 'plot.closeAfterSave', true);
cfg.plot.figureWindowStyle = get_nested_field(cfg, 'plot.figureWindowStyle', 'normal');
cfg.plot.resolution = get_nested_field(cfg, 'plot.resolution', 300);
cfg.plot.phaseCLim = get_nested_field(cfg, 'plot.phaseCLim', [-180, 180]);
cfg.plot.interpreter = get_nested_field(cfg, 'plot.interpreter', 'none');
cfg.plot.wgShadeColor = get_nested_field(cfg, 'plot.wgShadeColor', [0.85, 0.85, 0.85]);
cfg.plot.wgShadeAlpha = get_nested_field(cfg, 'plot.wgShadeAlpha', 0.45);
cfg.plot.periodYLimMode = get_nested_field(cfg, 'plot.periodYLimMode', 'design_pm');
cfg.plot.periodYLimHalfRange = get_nested_field(cfg, 'plot.periodYLimHalfRange', 1.0);
cfg.plot.periodErrorYLimHalfRange = get_nested_field(cfg, 'plot.periodErrorYLimHalfRange', 1.0);
cfg.plot.batchNotesPanel = get_nested_field(cfg, 'plot.batchNotesPanel', true);

if ~isfield(cfg, 'centerPicker'); cfg.centerPicker = struct(); end
cfg.centerPicker.skipExisting = get_nested_field(cfg, 'centerPicker.skipExisting', true);
cfg.centerPicker.method = get_nested_field(cfg, 'centerPicker.method', 'manual_radial_lines');

if ~isfield(cfg, 'centerOpt'); cfg.centerOpt = struct(); end
cfg.centerOpt.enable = get_nested_field(cfg, 'centerOpt.enable', true);
cfg.centerOpt.searchRange = get_nested_field(cfg, 'centerOpt.searchRange', 1.0);
cfg.centerOpt.searchStep = get_nested_field(cfg, 'centerOpt.searchStep', 0.05);
cfg.centerOpt.rStep = get_nested_field(cfg, 'centerOpt.rStep', 0.10);
cfg.centerOpt.fitRadiusRange = get_nested_field(cfg, 'centerOpt.fitRadiusRange', []);
cfg.centerOpt.metricMode = get_nested_field(cfg, 'centerOpt.metricMode', 'median_abs');
cfg.centerOpt.minValidRadii = get_nested_field(cfg, 'centerOpt.minValidRadii', 3);
cfg.centerOpt.minNPeriods = get_nested_field(cfg, 'centerOpt.minNPeriods', 2);
cfg.centerOpt.maxPeriodStd_um = get_nested_field(cfg, 'centerOpt.maxPeriodStd_um', Inf);
cfg.centerOpt.maxAbsPeriodError_um = get_nested_field(cfg, 'centerOpt.maxAbsPeriodError_um', Inf);

if ~isfield(cfg, 'extract'); cfg.extract = struct(); end
cfg.extract.phaseSmoothWin = get_nested_field(cfg, 'extract.phaseSmoothWin', ...
    get_nested_field(cfg, 'extract.smoothWindow', 9));
cfg.extract.binarySmoothWin = get_nested_field(cfg, 'extract.binarySmoothWin', 7);
cfg.extract.minSegmentPts = get_nested_field(cfg, 'extract.minSegmentPts', 3);
cfg.extract.minPeriodUm = get_nested_field(cfg, 'extract.minPeriodUm', 1.0);
cfg.extract.maxPeriodUm = get_nested_field(cfg, 'extract.maxPeriodUm', 5.0);

if ~isfield(cfg, 'naming'); cfg.naming = struct(); end
cfg.naming.rawFilePattern = get_nested_field(cfg, 'naming.rawFilePattern', ...
    '^(?<prefix>.+)_r(?<row>\d+)c(?<col>\d+)_(?<scanID>\d+)$');
cfg.naming.rawFileExt = get_nested_field(cfg, 'naming.rawFileExt', '.txt');
cfg.naming.defaultPhaseFilePattern = get_nested_field(cfg, 'naming.defaultPhaseFilePattern', '');
cfg.naming.deviceIDFormat = get_nested_field(cfg, 'naming.deviceIDFormat', '%s_r%dc%d');
cfg.naming.designIDFromPrefix = get_nested_field(cfg, 'naming.designIDFromPrefix', true);

try
    if ~isempty(cfg.plot.figureWindowStyle)
        set(groot, 'DefaultFigureWindowStyle', cfg.plot.figureWindowStyle);
    end
catch
end

end

function val = get_nested_field(S, path, defaultVal)
    parts = strsplit(path, '.');
    val = S;
    for ii = 1:numel(parts)
        if isstruct(val) && isfield(val, parts{ii})
            val = val.(parts{ii});
        else
            val = defaultVal;
            return;
        end
    end
    if isempty(val)
        val = defaultVal;
    end
end
