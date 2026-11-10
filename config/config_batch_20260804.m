function cfg = config_batch_20260804()
%CONFIG_BATCH_20260804 Batch settings for the 20260804 U r4c1-r4c6 scans.
%
% Design metadata for this batch uses a 50 um reference radius and a
% 2.5 um reference period. The detailed geometry is stored in designs.csv.

cfg = config_batch_20260521_1();
cfg.batchName = '20260804';
cfg = configure_local_batch_paths(cfg);

cfg.naming.rawFilePattern = ...
    '^(?<prefix>U)_R(?<row>\d+)C(?<col>\d+)_(?<scanID>\d+)$';

cfg.centerPicker.displaySignal = 'inphase';

end
