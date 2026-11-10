function cfg = config_afm_20260914_AFM()
%CONFIG_AFM_20260914_AFM AFM topography batch configuration for 20260914_AFM.
%
% Workflow:
%   main_afm_generate_metadata
%   main_afm_plot_channels
%   main_afm_analyze_batch
%
% Analysis chain: detect the waveguide angle, level the height with a plane
% fitted only on the far-field regions outside the ridge and trenches, then
% slice perpendicular to the waveguide and measure step heights.
%
% Sample tag: 600etch400 = 600 nm film thickness, 400 nm designed etch depth.

cfg = struct();

%% =========================
%  1. Batch identity
% =========================
cfg.batchName = '20260914_AFM';

%% =========================
%  2. Project paths
% =========================
projectRoot = fileparts(fileparts(mfilename('fullpath')));
cfg.paths.projectRoot = projectRoot;

% Raw data, metadata, and generated results live in the private batch
% folder local/batches/<batchName>/.
cfg = configure_local_batch_paths(cfg);

%% =========================
%  3. Run behavior
% =========================
cfg.run.skipExisting = false;    % AFM scans are small; reprocess by default
cfg.run.forceReprocess = true;
cfg.run.regenerateFigures = true;

%% =========================
%  4. Raw files and naming
% =========================
cfg.afm.rawFileExt = '.txt';
cfg.afm.naming.pattern = '^(?<sample>.+)_gain(?<gain>[0-9p]+)_?(?<scanID>\d+)?$';
cfg.afm.headerTokens = {'Height_Sensor'};

%% =========================
%  5. Channels
% =========================
cfg.afm.heightField = 'Height_Sensor';   % primary topography channel
cfg.afm.crossCheckField = 'Height';      % cross-check channel (different scale)

%% =========================
%  6. Expected geometry
% =========================
cfg.afm.expectedDepth_nm = 400;   % designed etch depth for tag 600etch400

%% =========================
%  7. Waveguide orientation
% =========================
% Detected from the dominant edge orientation (gradient histogram).
cfg.afm.orientation.override_deg = [];   % set a number to skip detection
cfg.afm.orientation.gradientPercentile = 90;
cfg.afm.orientation.smoothBins = 5;
cfg.afm.orientation.peakWindow_deg = 5;

%% =========================
%  8. Far-field leveling
% =========================
cfg.afm.level.method = 'farfield_plane';  % farfield_plane | plane | plane_line | none
cfg.afm.level.moatSearch_um = 0.6;        % search floor minimum outward from each edge
cfg.afm.level.moatWindow_um = 0.05;       % robust window around the moat minimum
cfg.afm.level.farFieldMargin_um = 0.1;    % far field starts this far beyond the moat
cfg.afm.level.plateauLeveling = true;     % per-plateau plane fit for the ridge top

%% =========================
%  9. Cross-waveguide profile and plateau detection
% =========================
cfg.afm.profile.bins = [];                % [] = image size
cfg.afm.plateau.topTolerance_nm = 20;     % fallback top band below the peak
cfg.afm.plateau.topFlatSlope_nm_per_um = 50;  % flattest-segment slope limit
cfg.afm.plateau.minTopWidth_um = 0.05;    % fallback if the flat segment is too short
cfg.afm.plateau.edgeLevelFraction = 0.5;  % threshold between top and floor
cfg.afm.plateau.minRidgeWidth_um = 0.2;

%% =========================
%  10. Sidewall angle
% =========================
cfg.afm.sidewall.lowFraction = 0.10;      % 10-90% of the local step height
cfg.afm.sidewall.highFraction = 0.90;
cfg.afm.sidewall.nSlices = 120;           % per-slice angles for uniformity

%% =========================
%  11. Quality metrics
% =========================
cfg.afm.quality.rowJumpThreshold_nm = 15;  % row-median jump flag

%% =========================
%  12. Plot options
% =========================
cfg.plot.resolution = 300;
cfg.plot.showFigures = false;
cfg.plot.saveFigures = true;
cfg.plot.closeAfterSave = true;
cfg.plot.figureWindowStyle = 'normal';
cfg.plot.save3d = true;                    % per-scan 3-D surface PNG
cfg.plot.save3dTrueScale = true;           % also a true-scale 3-D PNG
cfg.plot.surfaceDownsample = 2;
cfg.plot.verticalExaggeration = 8;

%% =========================
%  13. Raw QC heatmaps
% =========================
cfg.rawHeatmap.reader = 'nanoscope_channels';
cfg.rawHeatmap.headerTokens = {'Height_Sensor'};
cfg.rawHeatmap.rawExt = '.txt';
cfg.rawHeatmap.saveOverview = true;
cfg.rawHeatmap.channels = {};

end
