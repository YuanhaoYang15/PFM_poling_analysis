function cfg = config_batch_20260521_3()
%CONFIG_BATCH_20260521_3 Batch settings for the 20260521 UR r4c1/r4c2 scans.
%
% Design metadata for this batch should use the 50 um radius and 2.5 um
% period entries in local/batches/20260521_3/metadata/designs.csv.

cfg = config_batch_20260521_1();
cfg.batchName = '20260521_3';
cfg = configure_local_batch_paths(cfg);

% Production scans use uppercase R/C raw names in this batch.
cfg.naming.rawFilePattern = '^(?<prefix>UR)_R(?<row>\d+)C(?<col>\d+)_(?<scanID>\d+)$';

% Manual initial-center picking for this batch should display inphase.
cfg.centerPicker.displaySignal = 'inphase';

end
