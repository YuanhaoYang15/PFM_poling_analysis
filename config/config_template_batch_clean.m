function cfg = config_template_batch_clean()
%CONFIG_TEMPLATE_BATCH_CLEAN Clean batch-level configuration template for PFM poling analysis.
%
% How to use:
%   1. Copy this file to config/config_batch_<batchName>.m
%   2. Rename the function to config_batch_<batchName>
%   3. Set cfg.batchName = '<batchName>'
%
% Example:
%   file name: config_batch_20260511_1.m
%   function:  cfg = config_batch_20260511_1()
%   batchName: '20260511_1'
%
% Important:
%   This template is intentionally single-pass. Do NOT append old
%   "recommended additions" blocks at the end. Each parameter appears once.

cfg = struct();

%% =========================
%  1. Batch identity
% =========================
cfg.batchName = 'CHANGE_ME';   % e.g. '20260511_1'

%% =========================
%  2. Project paths
% =========================
projectRoot = fileparts(fileparts(mfilename('fullpath')));
cfg.paths.projectRoot = projectRoot;

% Raw data, metadata, centers, and generated results live in one private
% local batch folder by default: local/batches/<batchName>/.
cfg = configure_local_batch_paths(cfg);

%% =========================
%  3. Run behavior
% =========================
cfg.run.skipExisting = true;                  % reuse existing processed scan results
cfg.run.forceReprocess = false;               % true = reprocess everything
cfg.run.regenerateFiguresForExisting = false; % true = recreate figures from saved results

%% =========================
%  4. Raw text preprocessing
% =========================
cfg.preprocess.enable = true;
cfg.preprocess.useCache = true;
cfg.preprocess.cacheFolderName = 'preprocessed_cache';

% Default reader: stable legacy NanoScope ASCII reader.
cfg.preprocess.reader = 'nanoscope_legacy';
cfg.preprocess.phaseField = 'LS_PR_Phase';

% Used only when scan phaseFilePattern is empty and rawName points to a folder.
cfg.preprocess.phaseFileKeywords = {'phase', 'pfm', 'pr'};

% If a raw text file only contains a phase matrix with no x/y coordinates,
% use scanSizeUm in the design table if available. Otherwise fallback here.
cfg.preprocess.scanSizeUm = [];
cfg.preprocess.pixelSizeUm = 1.0;

cfg.preprocess.phaseUnit = 'deg';       % 'deg' or 'rad'
cfg.preprocess.phaseOffsetDeg = 0;

% Legacy compatibility switches. Usually not important for NanoScope reader.
cfg.preprocess.detectAxisInMatrix = true;
cfg.preprocess.useLargestNumericBlock = true;
cfg.preprocess.coordUnit = 'auto';

%% =========================
%  6. Optional legacy MAT loading variable names
% =========================
cfg.load.xVar = '';
cfg.load.yVar = '';
cfg.load.phaseVar = '';

%% =========================
%  7. Circular arc sampling
% =========================
% thetaRange = [] means automatically use the longest valid visible arc.
% nTheta is the number of samples around the full circle.
% For large-radius designs, increase nTheta to keep arc-length sampling dense.
cfg.arc.thetaRange = [];
cfg.arc.nTheta = 8000;
cfg.arc.ds_um = 0.04;
cfg.arc.edgeTrimFraction = 0.03;

%% Domain extraction
cfg.extract.phaseSmooth_um  = 0.30;
cfg.extract.binarySmooth_um = 0.20;
cfg.extract.minSegment_um   = 0.10;

% fallback old parameters
cfg.extract.phaseSmoothWin  = 9;
cfg.extract.binarySmoothWin = 7;
cfg.extract.minSegmentPts   = 3;

%% =========================
%  8. Phase processing and domain extraction
% =========================
cfg.extract.minPeriodUm = 1.0;
cfg.extract.maxPeriodUm = 5.0;

% Legacy extraction parameters.
cfg.extract.phaseSmoothWin  = 9;
cfg.extract.binarySmoothWin = 7;
cfg.extract.minSegmentPts   = 3;

% Compatibility / optional QC parameters.
cfg.extract.smoothWindow = 7;
cfg.extract.minDomainFraction = 0.08;
cfg.extract.useKmeans = true;
cfg.extract.outlierSigma = 3.0;
cfg.extract.verbose = true;

%% =========================
%  9. Center picking
% =========================
% Inphase: no picking is needed when no saved center exists. A saved center
% is preferred as a local-search start; set preferManual=false to ignore it.
cfg.centerInit.method = 'auto';          % 'auto' | 'manual' (requires a center)
cfg.centerInit.preferManual = true;
cfg.centerPicker.skipExisting = true;
cfg.centerPicker.method = 'manual_radial_lines';
cfg.centerPicker.displaySignal = 'phase';  % 'phase' or 'inphase'

%% =========================
%  10. Center optimization
% =========================
cfg.centerOpt.enable = true;
cfg.centerOpt.method = 'coherence';      % 'coherence' | 'grid' (legacy)

% Legacy grid settings. To recover the old inphase path use method='grid'
% together with centerInit.method='manual'.
cfg.centerOpt.searchRange = 1.0;        % um, +/- range in x and y
cfg.centerOpt.searchStep  = 0.05;       % um

% Radius step used only during center optimization.
cfg.centerOpt.rStep = 0.10;

% Radius range used to judge period error for center correction.
% [] means waveguide region [R0-w/2, R0+w/2].
% For large-radius / small-FOV data, consider a wider range, e.g. [47, 55].
cfg.centerOpt.fitRadiusRange = [];

% Optimization metric / QC.
cfg.centerOpt.metricMode = 'median_abs';
cfg.centerOpt.minValidRadii = 3;
cfg.centerOpt.minNPeriods = 2;
cfg.centerOpt.maxPeriodStd_um = Inf;
cfg.centerOpt.maxAbsPeriodError_um = Inf;

% Stripe harmonic search: global only when no start center was supplied.
cfg.centerOpt.coherence.radiusRange = []; % [] = [rMin, rMax]
cfg.centerOpt.coherence.taper_um = 0.5;
cfg.centerOpt.coherence.minPixels = 2000;
cfg.centerOpt.coherence.localRange_um = 5.0; % 3.0 after the global search
cfg.centerOpt.coherence.coarseStep_um = 0.5;
cfg.centerOpt.coherence.fineRange_um = 0.75;
cfg.centerOpt.coherence.fineStep_um = 0.125;
cfg.centerOpt.coherence.globalDistanceHalfRange_um = []; % half image diagonal
cfg.centerOpt.coherence.globalDistanceStep_um = 0.5;
cfg.centerOpt.coherence.globalTangentialStep_um = 1.75;
cfg.centerOpt.coherence.globalDecimate = 2;
cfg.centerOpt.coherence.minPeakRatio = 1.2;
cfg.centerOpt.coherence.minCoherence = 0.45;
cfg.centerOpt.coherence.maxFinalPeriodError_um = 0.03;

% Robust radial period zero crossing; rejected adjustments remain QC notes.
cfg.centerOpt.radialPolish.enable = true;
cfg.centerOpt.radialPolish.range_um = 0.6;
cfg.centerOpt.radialPolish.step_um = 0.05;
cfg.centerOpt.radialPolish.minSamples = 5;
cfg.centerOpt.radialPolish.agreeTolerance_um = 0.10;
cfg.centerOpt.radialPolish.minAgreeFraction = 0.5;

% Legacy grid: if a best center reaches the search edge, refine once with a smaller
% search box biased toward the unexplored outward side.
cfg.centerOpt.edgeRefine.enable = true;
cfg.centerOpt.edgeRefine.maxPasses = 2;
cfg.centerOpt.edgeRefine.rangeScale = 0.5;
cfg.centerOpt.edgeRefine.outwardFraction = 0.75;
cfg.centerOpt.edgeRefine.boundaryStepTolerance = 1.0;

%% =========================
%  11. Plot options
% =========================
cfg.plot.resolution = 300;
cfg.plot.phaseCLim = [-180, 180];

% Batch mode should usually save figures without opening many windows.
cfg.plot.showFigures = false;
cfg.plot.saveFigures = true;
cfg.plot.closeAfterSave = true;
cfg.plot.figureWindowStyle = 'docked';  % use 'normal' if preferred

cfg.plot.interpreter = 'none';
cfg.plot.wgShadeColor = [0.85, 0.85, 0.85];
cfg.plot.wgShadeAlpha = 0.45;

% Period plot y-limits.
cfg.plot.periodYLimMode = 'design_pm';
cfg.plot.periodYLimHalfRange = 1.0;       % um
cfg.plot.periodErrorYLimHalfRange = 1.0;  % um

%% =========================
%  12. Metadata generation from raw filenames
% =========================
cfg.naming.rawFilePattern = '^(?<prefix>.+)_r(?<row>\d+)c(?<col>\d+)_(?<scanID>\d+)$';
cfg.naming.rawFileExt = '.txt';
cfg.naming.defaultPhaseFilePattern = '';
cfg.naming.deviceIDFormat = '%s_r%dc%d';
cfg.naming.designIDFromPrefix = true;

end
