function cfg = config_batch_20260521_2()
%CONFIG_BATCH_20260521_2 Batch settings for the 20260521 UR r1c7/r1c8 scans.

cfg = config_batch_20260521_1();
cfg.batchName = '20260521_2';
cfg = configure_local_batch_paths(cfg);

% Production scans use uppercase R/C raw names in this batch.
cfg.naming.rawFilePattern = '^(?<prefix>UR)_R(?<row>\d+)C(?<col>\d+)_(?<scanID>\d+)$';

% Manual initial-center picking for this batch should display inphase.
cfg.centerPicker.displaySignal = 'inphase';

end
