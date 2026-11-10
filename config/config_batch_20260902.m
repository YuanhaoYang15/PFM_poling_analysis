function cfg = config_batch_20260902()
%CONFIG_BATCH_20260902 Batch settings for the 20260902 SPN Chip2B1 RT scans.
%
% Design metadata uses a 40 um reference radius and a 2.75 um reference
% period. Geometry and device poling notes are stored in batch metadata.

cfg = config_batch_20260521_1();
cfg.batchName = '20260902';
cfg = configure_local_batch_paths(cfg);

cfg.naming.rawFilePattern = ...
    '^(?<prefix>SPN_Chip2B1_RT)_R(?<row>\d+)C(?<col>\d+)_(?<scanID>\d+)$';

cfg.centerPicker.displaySignal = 'inphase';

end
