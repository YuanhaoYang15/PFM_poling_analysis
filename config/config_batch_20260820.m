function cfg = config_batch_20260820()
%CONFIG_BATCH_20260820 Batch settings for the 20260820 SPN Chip2A BR scans.
%
% Design metadata for this batch uses a 40 um reference radius and a
% 2.75 um reference period. The detailed geometry is stored in designs.csv.

cfg = config_batch_20260521_1();
cfg.batchName = '20260820';
cfg = configure_local_batch_paths(cfg);

cfg.naming.rawFilePattern = ...
    '^(?<prefix>SPN_Chip2A_BR)_R(?<row>\d+)C(?<col>\d+)_(?<scanID>\d+)$';

cfg.centerPicker.displaySignal = 'inphase';

end
