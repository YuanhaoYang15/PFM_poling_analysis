function cfg = set_default_afm_options(cfg)
%SET_DEFAULT_AFM_OPTIONS Fill missing AFM config fields with safe defaults.

if ~isfield(cfg, 'run'); cfg.run = struct(); end
cfg.run.skipExisting = get_nested_field(cfg, 'run.skipExisting', true);
cfg.run.forceReprocess = get_nested_field(cfg, 'run.forceReprocess', false);
cfg.run.regenerateFigures = get_nested_field(cfg, 'run.regenerateFigures', false);

if ~isfield(cfg, 'plot'); cfg.plot = struct(); end
cfg.plot.showFigures = get_nested_field(cfg, 'plot.showFigures', false);
cfg.plot.saveFigures = get_nested_field(cfg, 'plot.saveFigures', true);
cfg.plot.closeAfterSave = get_nested_field(cfg, 'plot.closeAfterSave', true);
cfg.plot.figureWindowStyle = get_nested_field(cfg, 'plot.figureWindowStyle', 'normal');
cfg.plot.resolution = get_nested_field(cfg, 'plot.resolution', 300);
cfg.plot.interpreter = get_nested_field(cfg, 'plot.interpreter', 'none');

if ~isfield(cfg, 'afm'); cfg.afm = struct(); end
cfg.afm.rawFileExt = get_nested_field(cfg, 'afm.rawFileExt', '.txt');
cfg.afm.headerTokens = get_nested_field(cfg, 'afm.headerTokens', {'Height_Sensor'});
cfg.afm.heightField = get_nested_field(cfg, 'afm.heightField', 'Height_Sensor');
cfg.afm.crossCheckField = get_nested_field(cfg, 'afm.crossCheckField', 'Height');
cfg.afm.expectedDepth_nm = get_nested_field(cfg, 'afm.expectedDepth_nm', NaN);

patternDefault = '^(?<sample>.+)_gain(?<gain>[0-9p]+)_?(?<scanID>\d+)?$';
pattern = get_nested_field(cfg, 'afm.naming.pattern', patternDefault);
if ~isfield(cfg.afm, 'naming'); cfg.afm.naming = struct(); end
cfg.afm.naming.pattern = pattern;

if ~isfield(cfg.afm, 'orientation'); cfg.afm.orientation = struct(); end
cfg.afm.orientation.override_deg = get_nested_field(cfg, ...
    'afm.orientation.override_deg', []);
cfg.afm.orientation.gradientPercentile = get_nested_field(cfg, ...
    'afm.orientation.gradientPercentile', 90);
cfg.afm.orientation.smoothBins = get_nested_field(cfg, ...
    'afm.orientation.smoothBins', 5);
cfg.afm.orientation.peakWindow_deg = get_nested_field(cfg, ...
    'afm.orientation.peakWindow_deg', 5);

if ~isfield(cfg.afm, 'level'); cfg.afm.level = struct(); end
cfg.afm.level.method = get_nested_field(cfg, 'afm.level.method', 'farfield_plane');
cfg.afm.level.moatSearch_um = get_nested_field(cfg, 'afm.level.moatSearch_um', 0.6);
cfg.afm.level.moatWindow_um = get_nested_field(cfg, 'afm.level.moatWindow_um', 0.05);
cfg.afm.level.farFieldMargin_um = get_nested_field(cfg, ...
    'afm.level.farFieldMargin_um', 0.1);
cfg.afm.level.plateauLeveling = get_nested_field(cfg, 'afm.level.plateauLeveling', true);

if ~isfield(cfg.afm, 'profile'); cfg.afm.profile = struct(); end
cfg.afm.profile.bins = get_nested_field(cfg, 'afm.profile.bins', []);

if ~isfield(cfg.afm, 'plateau'); cfg.afm.plateau = struct(); end
cfg.afm.plateau.topTolerance_nm = get_nested_field(cfg, 'afm.plateau.topTolerance_nm', 20);
cfg.afm.plateau.topFlatSlope_nm_per_um = get_nested_field(cfg, ...
    'afm.plateau.topFlatSlope_nm_per_um', 50);
cfg.afm.plateau.minTopWidth_um = get_nested_field(cfg, ...
    'afm.plateau.minTopWidth_um', 0.05);
cfg.afm.plateau.edgeLevelFraction = get_nested_field(cfg, ...
    'afm.plateau.edgeLevelFraction', 0.5);
cfg.afm.plateau.minRidgeWidth_um = get_nested_field(cfg, ...
    'afm.plateau.minRidgeWidth_um', 0.2);

if ~isfield(cfg.afm, 'quality'); cfg.afm.quality = struct(); end
cfg.afm.quality.rowJumpThreshold_nm = get_nested_field(cfg, ...
    'afm.quality.rowJumpThreshold_nm', 15);

if ~isfield(cfg.afm, 'sidewall'); cfg.afm.sidewall = struct(); end
cfg.afm.sidewall.lowFraction = get_nested_field(cfg, ...
    'afm.sidewall.lowFraction', 0.10);
cfg.afm.sidewall.highFraction = get_nested_field(cfg, ...
    'afm.sidewall.highFraction', 0.90);
cfg.afm.sidewall.nSlices = get_nested_field(cfg, 'afm.sidewall.nSlices', 120);

cfg.plot.save3d = get_nested_field(cfg, 'plot.save3d', true);
cfg.plot.save3dTrueScale = get_nested_field(cfg, 'plot.save3dTrueScale', true);
cfg.plot.surfaceDownsample = get_nested_field(cfg, 'plot.surfaceDownsample', 2);
cfg.plot.verticalExaggeration = get_nested_field(cfg, ...
    'plot.verticalExaggeration', 8);

if isfield(cfg, 'paths') && isfield(cfg.paths, 'resultRoot')
    cfg.paths.afmResultRoot = get_nested_field(cfg, 'paths.afmResultRoot', ...
        fullfile(cfg.paths.resultRoot, 'afm'));
    cfg.paths.afmProcessedRoot = get_nested_field(cfg, 'paths.afmProcessedRoot', ...
        fullfile(cfg.paths.afmResultRoot, 'processed_data'));
    cfg.paths.afmFigureRoot = get_nested_field(cfg, 'paths.afmFigureRoot', ...
        fullfile(cfg.paths.afmResultRoot, 'figures'));
    cfg.paths.afmQcRoot = get_nested_field(cfg, 'paths.afmQcRoot', ...
        fullfile(cfg.paths.afmResultRoot, 'raw_qc'));
end

if isfield(cfg, 'metadata') && isfield(cfg.paths, 'metadataRoot')
    cfg.metadata.afmScansFile = get_nested_field(cfg, 'metadata.afmScansFile', ...
        fullfile(cfg.paths.metadataRoot, 'afm_scans.csv'));
end

if ~isfield(cfg, 'rawHeatmap'); cfg.rawHeatmap = struct(); end
cfg.rawHeatmap.reader = get_nested_field(cfg, 'rawHeatmap.reader', 'nanoscope_channels');
cfg.rawHeatmap.headerTokens = get_nested_field(cfg, 'rawHeatmap.headerTokens', ...
    cfg.afm.headerTokens);
cfg.rawHeatmap.rawExt = get_nested_field(cfg, 'rawHeatmap.rawExt', cfg.afm.rawFileExt);
cfg.rawHeatmap.saveOverview = get_nested_field(cfg, 'rawHeatmap.saveOverview', true);
cfg.rawHeatmap.channels = get_nested_field(cfg, 'rawHeatmap.channels', {});
if isfield(cfg, 'paths') && isfield(cfg.paths, 'afmQcRoot')
    cfg.rawHeatmap.outputRoot = get_nested_field(cfg, 'rawHeatmap.outputRoot', ...
        cfg.paths.afmQcRoot);
end

try
    if ~isempty(cfg.plot.figureWindowStyle)
        set(groot, 'DefaultFigureWindowStyle', cfg.plot.figureWindowStyle);
    end
catch
end

end
