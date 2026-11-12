function cfg = config_batch_20261112()
%CONFIG_BATCH_20261112 Batch settings for the 20261112 SPN chip3a1 test scans.
%
% Raw names use the sample prefix SPN_chip3t; the electrode layout is
% SPN_chip3a1. Two fixed poling-test designs are present:
%   UL: R = 50 um, 110 fingers (Layer 1 ring 45-55 um)
%   LL: R = 30 um,  66 fingers (Layer 1 ring 25-35 um)
% Both have a nominal period of 2.85 um at R. The metadata uses the actual
% period 2*pi*R/N at Rref = R, so the coherence harmonic equals N.
%
% Single-electrode scans (SPN_chip3t_<UL|LL>_R<row>C<col>_<scan>) match the
% raw-name pattern below. The UL big-pad scans (SPN_chip3t_UL_B1..B3) have
% no row/column in their names; their metadata rows are written by hand and
% preserved by metadata regeneration.

cfg = config_batch_20260902();
cfg.batchName = '20261112';
cfg = configure_local_batch_paths(cfg);

cfg.naming.rawFilePattern = ...
    '^(?<prefix>SPN_chip3t_(?:UL|LL))_R(?<row>\d+)C(?<col>\d+)_(?<scanID>\d+)$';

cfg.centerPicker.displaySignal = 'inphase';

end
