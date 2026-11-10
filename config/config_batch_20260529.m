function cfg = config_batch_20260529()
%CONFIG_BATCH_20260529 Batch settings for the 20260529 UR r4c6-r4c9 scans.
%
% Design metadata for this batch uses the 50 um radius and 3 um period
% entries in local/batches/20260529/metadata/designs.csv.

cfg = config_batch_20260521_1();
cfg.batchName = '20260529';
cfg = configure_local_batch_paths(cfg);

% Production scans use uppercase R/C raw names in this batch.
cfg.naming.rawFilePattern = '^(?<prefix>UR)_R(?<row>\d+)C(?<col>\d+)_(?<scanID>\d+)$';

% Manual initial-center picking for this batch should display inphase.
cfg.centerPicker.displaySignal = 'inphase';

end
