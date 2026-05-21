function cfg = config_batch_20260521_1()
%CONFIG_BATCH_20260521_1 Batch settings for the 20260521 UR scans.
%
% This batch uses the same 30 um / 2.5 um baseline analysis settings as
% config_batch_20260511. Only the batch paths and raw-name filter differ.

cfg = config_batch_20260511();
cfg.batchName = '20260521_1';

cfg = configure_local_batch_paths(cfg);

% Keep non-UR test exports in the batch raw folder without letting metadata
% generation pick them up as production scans.
cfg.naming.rawFilePattern = '^(?<prefix>UR)_R(?<row>\d+)C(?<col>\d+)_(?<scanID>\d+)$';
cfg.centerPicker.displaySignal = 'inphase';

% The manually picked initial centers are approximate; search a wider
% neighborhood before extracting the final batch summary.
cfg.centerOpt.searchRange = 3.0;

end
