function cfg = config_template()
%CONFIG_DEVICE_NAME Device-level configuration.
%
% This version accepts raw PFM text-export folders directly.
% You do NOT need to manually generate .mat files before running the package.

cfg = struct();

%% Basic information
cfg.deviceName = 'DEVICE_NAME';

%% Paths
projectRoot = fileparts(fileparts(mfilename('fullpath')));
cfg.paths.projectRoot = projectRoot;

% -------------------------------------------------------------------------
% Raw data path
% -------------------------------------------------------------------------
% Recommended:
%   Keep raw PFM txt data OUTSIDE this code repository.
%
% Method 1, direct absolute path:
%   cfg.paths.rawTxtRoot = 'D:\Data\PFM_raw_txt';
%
% Method 2, local private path file:
%   Copy local/local_paths_template.m to local/local_paths.m
%   and edit paths.rawTxtRoot there. local_paths.m is ignored by Git.
%
% If no local_paths.m exists, the fallback is projectRoot/raw_txt.
localDir = fullfile(projectRoot, 'local');
if exist(fullfile(localDir, 'local_paths.m'), 'file')
    addpath(localDir);
    localPaths = local_paths();
else
    localPaths = struct();
end

if isfield(localPaths, 'rawTxtRoot') && ~isempty(localPaths.rawTxtRoot)
    cfg.paths.rawTxtRoot = localPaths.rawTxtRoot;
else
    cfg.paths.rawTxtRoot = fullfile(projectRoot, 'raw_txt');  % fallback only
end

% Kept for compatibility. The loader can also read files from raw_data/.
cfg.paths.rawData = fullfile(projectRoot, 'raw_data');

% -------------------------------------------------------------------------
% Output path
% -------------------------------------------------------------------------
% By default, processed data and figures are saved inside the code project.
% If you also want outputs outside the repo, set paths.outputRoot in
% local/local_paths.m.
if isfield(localPaths, 'outputRoot') && ~isempty(localPaths.outputRoot)
    cfg.paths.processedData = fullfile(localPaths.outputRoot, 'processed_data', cfg.deviceName);
    cfg.paths.figures       = fullfile(localPaths.outputRoot, 'figures', cfg.deviceName);
else
    cfg.paths.processedData = fullfile(projectRoot, 'processed_data', cfg.deviceName);
    cfg.paths.figures       = fullfile(projectRoot, 'figures', cfg.deviceName);
end

%% Raw text preprocessing
% The loader first looks for each scan under cfg.paths.rawTxtRoot.
% Each scan can be either:
%   1. a folder containing exported txt files; or
%   2. a single txt/csv/dat/mat file.
%
% If the scan is a folder, the code searches for a phase file using
% scanCfg.phaseFilePattern first. If empty, it uses the keywords below.
cfg.preprocess.enable = true;
cfg.preprocess.useCache = true;
cfg.preprocess.cacheFolderName = 'preprocessed_cache';

% Used only when scanCfg.phaseFilePattern is empty.
cfg.preprocess.phaseFileKeywords = {'phase', 'pfm', 'pr'};

% If the raw text file only contains a phase matrix with no x/y axis,
% x/y axes are generated using one of the following:
%   cfg.preprocess.scanSizeUm = [xWidth, yHeight];  % recommended if known
%   or cfg.preprocess.pixelSizeUm = scalar;
cfg.preprocess.scanSizeUm = [];      % e.g. [40, 25], leave [] for auto/pixel
cfg.preprocess.pixelSizeUm = 1.0;

% Unit of phase values in the raw txt file.
cfg.preprocess.phaseUnit = 'deg';    % 'deg' or 'rad'
cfg.preprocess.phaseOffsetDeg = 0;

% Some exports use first row/first column as axes. Leave auto on.
cfg.preprocess.detectAxisInMatrix = true;

%% Legacy .mat loading variable names
% Only needed if a scan points to a .mat file and automatic detection fails.
cfg.load.xVar = '';
cfg.load.yVar = '';
cfg.load.phaseVar = '';

%% Device design
cfg.design.R0 = 30.0;                  % waveguide center radius, um
cfg.design.w  = 1.0;                   % waveguide width, um

cfg.design.periodRef.Rref = 30.0;      % reference radius, um
cfg.design.periodRef.LambdaRef = 2.5;  % designed period at Rref, um

%% Radius sampling
cfg.radius.rMin = 28.0;
cfg.radius.rMax = 35.0;
cfg.radius.dr   = 0.1;

%% Circular arc sampling
% [] means automatic detection of valid angular coverage from the image.
% You can manually set, for example: cfg.arc.thetaRange = [0, 70]*pi/180;
cfg.arc.thetaRange = [];
cfg.arc.nTheta = 1200;
cfg.arc.edgeTrimFraction = 0.03;

%% Phase processing and domain extraction
cfg.extract.smoothWindow = 7;
cfg.extract.minPeriodUm = 1.0;
cfg.extract.maxPeriodUm = 5.0;
cfg.extract.minDomainFraction = 0.08;
cfg.extract.useKmeans = true;
cfg.extract.outlierSigma = 3.0;
cfg.extract.verbose = true;

%% Center optimization
cfg.centerOpt.enable = true;
cfg.centerOpt.searchRange = 2.0;    % um around initial center
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

%% Scans
% rawName can be a folder or a single file under cfg.paths.rawTxtRoot.
% If centerInitial is left empty, run main_pick_initial_centers.m first.
% For folders, phaseFilePattern can be specified if automatic detection fails.
%
% Example folder:
%   raw_txt/Data_UF_2p5_r1c2_1_260511/
%
% Example single file:
%   raw_txt/Data_UF_2p5_r1c2_1_260511.txt

cfg.scans = struct([]);

cfg.scans(1).scanID = 1;
cfg.scans(1).rawName = 'Data_UF_2p5_r1c2_1_260511';  % relative to cfg.paths.rawTxtRoot, or absolute path
cfg.scans(1).phaseFilePattern = '*Phase*.txt';   % set '' for auto detection
cfg.scans(1).centerInitial = [];                 % [] means load from local/initial_centers_*.mat
cfg.scans(1).positionLabel = '';
cfg.scans(1).notes = '';

cfg.scans(2).scanID = 2;
cfg.scans(2).rawName = 'Data_UF_2p5_r1c2_2_260511';  % relative to cfg.paths.rawTxtRoot, or absolute path
cfg.scans(2).phaseFilePattern = '*Phase*.txt';   % set '' for auto detection
cfg.scans(2).centerInitial = [];                 % [] means load from local/initial_centers_*.mat
cfg.scans(2).positionLabel = '';
cfg.scans(2).notes = '';

end
