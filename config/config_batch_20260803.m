function cfg = config_batch_20260803()
%CONFIG_BATCH_20260803 Batch settings for the 20260803 DR r4c6-r4c9 scans.
%
% Design metadata uses the 50 um radius / 3 um period profile shared with
% the 20260529 batch: w = 1 um, r = 48:0.1:55 um.

cfg = config_batch_20260521_1();
cfg.batchName = '20260803';
cfg = configure_local_batch_paths(cfg);

cfg.naming.rawFilePattern = ...
    '^(?<prefix>DR)_R(?<row>\d+)C(?<col>\d+)_(?<scanID>\d+)$';

cfg.centerPicker.displaySignal = 'inphase';

end
