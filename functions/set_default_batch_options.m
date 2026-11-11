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

if ~isfield(cfg, 'centerPicker'); cfg.centerPicker = struct(); end
cfg.centerPicker.skipExisting = get_nested_field(cfg, 'centerPicker.skipExisting', true);
cfg.centerPicker.method = get_nested_field(cfg, 'centerPicker.method', 'manual_radial_lines');
cfg.centerPicker.displaySignal = get_nested_field(cfg, 'centerPicker.displaySignal', 'phase');

if ~isfield(cfg, 'centerInit'); cfg.centerInit = struct(); end
cfg.centerInit.method = get_nested_field(cfg, 'centerInit.method', 'auto');
cfg.centerInit.preferManual = get_nested_field(cfg, 'centerInit.preferManual', true);

if ~isfield(cfg, 'centerOpt'); cfg.centerOpt = struct(); end
cfg.centerOpt.enable = get_nested_field(cfg, 'centerOpt.enable', true);
cfg.centerOpt.method = get_nested_field(cfg, 'centerOpt.method', 'coherence');
cfg.centerOpt.searchRange = get_nested_field(cfg, 'centerOpt.searchRange', 1.0);
cfg.centerOpt.searchStep = get_nested_field(cfg, 'centerOpt.searchStep', 0.05);
cfg.centerOpt.rStep = get_nested_field(cfg, 'centerOpt.rStep', 0.10);
cfg.centerOpt.fitRadiusRange = get_nested_field(cfg, 'centerOpt.fitRadiusRange', []);
cfg.centerOpt.metricMode = get_nested_field(cfg, 'centerOpt.metricMode', 'median_abs');
cfg.centerOpt.minValidRadii = get_nested_field(cfg, 'centerOpt.minValidRadii', 3);
cfg.centerOpt.minNPeriods = get_nested_field(cfg, 'centerOpt.minNPeriods', 2);
cfg.centerOpt.maxPeriodStd_um = get_nested_field(cfg, 'centerOpt.maxPeriodStd_um', Inf);
cfg.centerOpt.maxAbsPeriodError_um = get_nested_field(cfg, 'centerOpt.maxAbsPeriodError_um', Inf);
if ~isfield(cfg.centerOpt, 'edgeRefine'); cfg.centerOpt.edgeRefine = struct(); end
cfg.centerOpt.edgeRefine.enable = get_nested_field(cfg, 'centerOpt.edgeRefine.enable', true);
cfg.centerOpt.edgeRefine.maxPasses = get_nested_field(cfg, 'centerOpt.edgeRefine.maxPasses', 2);
cfg.centerOpt.edgeRefine.rangeScale = get_nested_field(cfg, 'centerOpt.edgeRefine.rangeScale', 0.5);
cfg.centerOpt.edgeRefine.outwardFraction = get_nested_field(cfg, 'centerOpt.edgeRefine.outwardFraction', 0.75);
cfg.centerOpt.edgeRefine.boundaryStepTolerance = get_nested_field( ...
    cfg, 'centerOpt.edgeRefine.boundaryStepTolerance', 1.0);

if ~isfield(cfg.centerOpt, 'coherence'); cfg.centerOpt.coherence = struct(); end
cfg.centerOpt.coherence.radiusRange = get_nested_field(cfg, 'centerOpt.coherence.radiusRange', []);
cfg.centerOpt.coherence.taper_um = get_nested_field(cfg, 'centerOpt.coherence.taper_um', 0.5);
cfg.centerOpt.coherence.minPixels = get_nested_field(cfg, 'centerOpt.coherence.minPixels', 2000);
cfg.centerOpt.coherence.localRange_um = get_nested_field(cfg, 'centerOpt.coherence.localRange_um', 5.0);
cfg.centerOpt.coherence.coarseStep_um = get_nested_field(cfg, 'centerOpt.coherence.coarseStep_um', 0.5);
cfg.centerOpt.coherence.fineRange_um = get_nested_field(cfg, 'centerOpt.coherence.fineRange_um', 0.75);
cfg.centerOpt.coherence.fineStep_um = get_nested_field(cfg, 'centerOpt.coherence.fineStep_um', 0.125);
cfg.centerOpt.coherence.globalDistanceHalfRange_um = get_nested_field( ...
    cfg, 'centerOpt.coherence.globalDistanceHalfRange_um', []);
cfg.centerOpt.coherence.globalDistanceStep_um = get_nested_field( ...
    cfg, 'centerOpt.coherence.globalDistanceStep_um', 0.5);
cfg.centerOpt.coherence.globalTangentialStep_um = get_nested_field( ...
    cfg, 'centerOpt.coherence.globalTangentialStep_um', 1.75);
cfg.centerOpt.coherence.globalDecimate = get_nested_field(cfg, 'centerOpt.coherence.globalDecimate', 2);
cfg.centerOpt.coherence.minPeakRatio = get_nested_field(cfg, 'centerOpt.coherence.minPeakRatio', 1.2);
cfg.centerOpt.coherence.minCoherence = get_nested_field(cfg, 'centerOpt.coherence.minCoherence', 0.45);
cfg.centerOpt.coherence.maxFinalPeriodError_um = get_nested_field( ...
    cfg, 'centerOpt.coherence.maxFinalPeriodError_um', 0.03);

if ~isfield(cfg.centerOpt, 'radialPolish'); cfg.centerOpt.radialPolish = struct(); end
cfg.centerOpt.radialPolish.enable = get_nested_field(cfg, 'centerOpt.radialPolish.enable', true);
cfg.centerOpt.radialPolish.range_um = get_nested_field(cfg, 'centerOpt.radialPolish.range_um', 0.6);
cfg.centerOpt.radialPolish.step_um = get_nested_field(cfg, 'centerOpt.radialPolish.step_um', 0.05);
cfg.centerOpt.radialPolish.minSamples = get_nested_field(cfg, 'centerOpt.radialPolish.minSamples', 5);
cfg.centerOpt.radialPolish.agreeTolerance_um = get_nested_field( ...
    cfg, 'centerOpt.radialPolish.agreeTolerance_um', 0.10);
cfg.centerOpt.radialPolish.minAgreeFraction = get_nested_field( ...
    cfg, 'centerOpt.radialPolish.minAgreeFraction', 0.5);

if ~isfield(cfg, 'arc'); cfg.arc = struct(); end
cfg.arc.thetaRange = get_nested_field(cfg, 'arc.thetaRange', []);
cfg.arc.nTheta = get_nested_field(cfg, 'arc.nTheta', 8000);
cfg.arc.ds_um = get_nested_field(cfg, 'arc.ds_um', 0.04);
cfg.arc.edgeTrimFraction = get_nested_field(cfg, 'arc.edgeTrimFraction', 0.03);

if ~isfield(cfg, 'extract'); cfg.extract = struct(); end
cfg.extract.phaseSmoothWin = get_nested_field(cfg, 'extract.phaseSmoothWin', ...
    get_nested_field(cfg, 'extract.smoothWindow', 9));
cfg.extract.binarySmoothWin = get_nested_field(cfg, 'extract.binarySmoothWin', 7);
cfg.extract.minSegmentPts = get_nested_field(cfg, 'extract.minSegmentPts', 3);

% Physical-unit extraction controls. These are preferred over point-count
% controls when present.
cfg.extract.phaseSmooth_um = get_nested_field(cfg, 'extract.phaseSmooth_um', 0.30);
cfg.extract.binarySmooth_um = get_nested_field(cfg, 'extract.binarySmooth_um', 0.20);
cfg.extract.minSegment_um = get_nested_field(cfg, 'extract.minSegment_um', 0.10);

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
