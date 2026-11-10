function cfg = config_batch_20260825()
%CONFIG_BATCH_20260825 Plot-only settings for the LWG06 reference scans.
%
% These scans are not test-device data. The intended workflow is limited
% to direct raw-channel heatmaps; no normalization or device analysis is
% configured here.

cfg = config_batch_20260521_1();
cfg.batchName = '20260825';
cfg = configure_local_batch_paths(cfg);

% This imported batch predates the usual raw/ subfolder layout. Keep the
% original files in place and read TXT exports directly from the batch root.
cfg.paths.rawTxtRoot = cfg.paths.batchRoot;
cfg.paths.rawData = cfg.paths.rawTxtRoot;

cfg.naming.rawFileExt = '.txt';

cfg.rawHeatmap.channels = {};       % empty means every exported channel
cfg.rawHeatmap.saveOverview = true;
cfg.rawHeatmap.resolution = cfg.plot.resolution;
cfg.rawHeatmap.phaseCLim = cfg.plot.phaseCLim;

end
