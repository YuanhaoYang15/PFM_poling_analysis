function cfg = config_batch_20260506()
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
cfg.batchName = '20260506';   % e.g. '20260511_1'

%% =========================
%  2. Project paths
% =========================
projectRoot = fileparts(fileparts(mfilename('fullpath')));
cfg.paths.projectRoot = projectRoot;

% Raw data, metadata, centers, and generated results live in one private
% local batch folder by default: local/batches/<batchName>/.
cfg = configure_local_batch_paths(cfg);

%% =========================
%  4. Run behavior
% =========================
cfg.run.skipExisting = true;                  % reuse existing processed scan results
cfg.run.forceReprocess = false;               % true = reprocess everything
cfg.run.regenerateFiguresForExisting = false; % true = recreate figures from saved results

%% =========================
%  5. Raw text preprocessing
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
cfg.extract.binarySmooth_um = 0.30;
cfg.extract.minSegment_um   = 0.15;

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
cfg.centerPicker.skipExisting = true;
cfg.centerPicker.method = 'manual_radial_lines';

%% =========================
%  10. Center optimization
% =========================
cfg.centerOpt.enable = true;

% Search grid around the manually picked radial-line center.
cfg.centerOpt.searchRange = 1.5;        % um, +/- range in x and y
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
