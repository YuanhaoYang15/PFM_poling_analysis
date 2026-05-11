function cfg = config_batch_20260506()
%config_batch_20260506 Batch-level configuration for PFM poling analysis.
%
% This config describes one experimental batch, not one single device.
% Device-specific information is stored in metadata CSV files.

cfg = struct();

%% Batch information
cfg.batchName = '20260506';

%% Project paths
projectRoot = fileparts(fileparts(mfilename('fullpath')));
cfg.paths.projectRoot = projectRoot;

% Load machine-specific local paths if available.
localDir = fullfile(projectRoot, 'local');
if exist(fullfile(localDir, 'local_paths.m'), 'file')
    addpath(localDir);
    localPaths = local_paths();
else
    localPaths = struct();
end

% Raw data root for this batch.
rawRootField = matlab.lang.makeValidName(['batch_', cfg.batchName]);
if isfield(localPaths, 'rawRoots') && isfield(localPaths.rawRoots, rawRootField)
    cfg.paths.rawTxtRoot = localPaths.rawRoots.(rawRootField);
elseif isfield(localPaths, 'rawTxtRoot') && ~isempty(localPaths.rawTxtRoot)
    cfg.paths.rawTxtRoot = localPaths.rawTxtRoot;
else
    cfg.paths.rawTxtRoot = fullfile(projectRoot, 'raw_txt', cfg.batchName); % fallback only
end

% Output location.
if isfield(localPaths, 'outputRoot') && ~isempty(localPaths.outputRoot)
    cfg.paths.processedRoot = fullfile(localPaths.outputRoot, 'processed_data', cfg.batchName);
    cfg.paths.figureRoot    = fullfile(localPaths.outputRoot, 'figures', cfg.batchName);
else
    cfg.paths.processedRoot = fullfile(projectRoot, 'processed_data', cfg.batchName);
    cfg.paths.figureRoot    = fullfile(projectRoot, 'figures', cfg.batchName);
end

% Kept for compatibility with older single-device workflow.
cfg.paths.rawData = cfg.paths.rawTxtRoot;

%% Metadata files
cfg.metadata.designsFile = fullfile(projectRoot, 'metadata', ['designs_', cfg.batchName, '.csv']);
cfg.metadata.devicesFile = fullfile(projectRoot, 'metadata', ['devices_', cfg.batchName, '.csv']);
cfg.metadata.scansFile   = fullfile(projectRoot, 'metadata', ['scans_',   cfg.batchName, '.csv']);

%% Raw text preprocessing
cfg.preprocess.enable = true;
cfg.preprocess.useCache = true;
cfg.preprocess.cacheFolderName = 'preprocessed_cache';

% Used only when scan phaseFilePattern is empty and rawName points to a folder.
cfg.preprocess.phaseFileKeywords = {'phase', 'pfm', 'pr'};

% If a raw text file only contains a phase matrix with no x/y coordinates,
% use scanSizeUm in the design table if available. Otherwise fallback here.
cfg.preprocess.scanSizeUm = [];
cfg.preprocess.pixelSizeUm = 1.0;

cfg.preprocess.phaseUnit = 'deg';       % 'deg' or 'rad'
cfg.preprocess.phaseOffsetDeg = 0;
cfg.preprocess.detectAxisInMatrix = true;
cfg.preprocess.useLargestNumericBlock = true;
cfg.preprocess.coordUnit = 'auto';
cfg.preprocess.reader = 'nanoscope_legacy';
cfg.preprocess.phaseField = 'LS_PR_Phase';

%% Legacy .mat loading variable names
cfg.load.xVar = '';
cfg.load.yVar = '';
cfg.load.phaseVar = '';

%% Default circular arc sampling
% Individual design rows can override thetaMin/thetaMax if needed.
cfg.arc.thetaRange = [];
cfg.arc.nTheta = 1200;
cfg.arc.edgeTrimFraction = 0.03;

%% Default phase processing and domain extraction
cfg.extract.smoothWindow = 7;
cfg.extract.minPeriodUm = 1.0;
cfg.extract.maxPeriodUm = 5.0;
cfg.extract.minDomainFraction = 0.08;
cfg.extract.useKmeans = true;
cfg.extract.outlierSigma = 3.0;
cfg.extract.verbose = true;

cfg.extract.phaseSmoothWin  = 9;
cfg.extract.binarySmoothWin = 7;
cfg.extract.minSegmentPts   = 3;

%% Center picking
cfg.centerPicker.skipExisting = true;
cfg.centerPicker.method = 'manual_radial_lines';

%% Center optimization
cfg.centerOpt.enable = true;
cfg.centerOpt.searchRange = 2.0;
cfg.centerOpt.searchStep  = 0.10;   % use 0.05 for final high-accuracy run
cfg.centerOpt.rStep = 0.25;

cfg.centerOpt.weightPeriodError = 1.0;
cfg.centerOpt.weightPeriodStd   = 0.2;
cfg.centerOpt.weightNperiod     = 0.05;

%% Plot options
cfg.plot.resolution = 300;
cfg.plot.phaseCLim = [-180, 180];
cfg.plot.showFigures = true;
cfg.plot.interpreter = 'none';
cfg.plot.wgShadeColor = [0.85, 0.85, 0.85];
cfg.plot.wgShadeAlpha = 0.45;
%% Recommended additions to config_batch_20260511.m / config_batch_20260506.m
% Put these near the end of each config function, before the final "end".

%% Run behavior
cfg.run.skipExisting = true;              % reuse processed scan results
cfg.run.forceReprocess = false;           % true = reprocess everything
cfg.run.regenerateFiguresForExisting = false;

%% Figure behavior
cfg.plot.showFigures = false;             % batch mode: save figures without opening many windows
cfg.plot.saveFigures = true;
cfg.plot.closeAfterSave = true;
cfg.plot.figureWindowStyle = 'docked';    % use 'normal' if preferred
cfg.plot.periodYLimMode = 'design_pm';    % period ylim = design curve +/- half range
cfg.plot.periodYLimHalfRange = 1.0;       % um
cfg.plot.periodErrorYLimHalfRange = 1.0;  % um, for batch summary period-error plot

%% Center picking
cfg.centerPicker.skipExisting = true;
cfg.centerPicker.method = 'manual_radial_lines';

%% Center optimization
cfg.centerOpt.enable = true;
cfg.centerOpt.searchRange = 1.0;          % um around radial-line center
cfg.centerOpt.searchStep = 0.05;          % um
cfg.centerOpt.rStep = 0.10;               % radius step during center optimization
cfg.centerOpt.fitRadiusRange = [];        % [] = use waveguide region [R0-w/2, R0+w/2]
cfg.centerOpt.metricMode = 'median_abs';
cfg.centerOpt.minValidRadii = 3;
cfg.centerOpt.minNPeriods = 2;
cfg.centerOpt.maxPeriodStd_um = Inf;
cfg.centerOpt.maxAbsPeriodError_um = Inf;

%% Metadata generation from raw filenames
cfg.naming.rawFilePattern = '^(?<prefix>.+)_r(?<row>\d+)c(?<col>\d+)_(?<scanID>\d+)$';
cfg.naming.rawFileExt = '.txt';
cfg.naming.defaultPhaseFilePattern = '';
cfg.naming.deviceIDFormat = '%s_r%dc%d';
cfg.naming.designIDFromPrefix = true;


end
