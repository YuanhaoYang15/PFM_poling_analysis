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
