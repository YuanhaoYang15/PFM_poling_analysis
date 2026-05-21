function cfg = configure_local_batch_paths(cfg)
%CONFIGURE_LOCAL_BATCH_PATHS Set private batch paths under local/batches.

projectRoot = cfg.paths.projectRoot;
localDir = fullfile(projectRoot, 'local');
batchParent = fullfile(localDir, 'batches');

if exist(fullfile(localDir, 'local_paths.m'), 'file')
    addpath(localDir);
    localPaths = local_paths();
else
    localPaths = struct();
end

batchField = matlab.lang.makeValidName(['batch_', cfg.batchName]);
if isfield(localPaths, 'batchRoots') && isfield(localPaths.batchRoots, batchField)
    batchRoot = localPaths.batchRoots.(batchField);
elseif isfield(localPaths, 'batchParent') && ~isempty(localPaths.batchParent)
    batchRoot = fullfile(localPaths.batchParent, cfg.batchName);
else
    batchRoot = fullfile(batchParent, cfg.batchName);
end

cfg.paths.localRoot = localDir;
cfg.paths.batchRoot = batchRoot;
cfg.paths.rawTxtRoot = fullfile(batchRoot, 'raw');
cfg.paths.rawData = cfg.paths.rawTxtRoot;
cfg.paths.metadataRoot = fullfile(batchRoot, 'metadata');
cfg.paths.centerRoot = fullfile(batchRoot, 'centers');
cfg.paths.selectionRoot = fullfile(batchRoot, 'selected_scans');

cfg.paths.resultRoot = fullfile(batchRoot, 'results');
cfg.paths.phaseResultRoot = fullfile(cfg.paths.resultRoot, 'phase');
cfg.paths.processedRoot = fullfile(cfg.paths.phaseResultRoot, 'processed_data');
cfg.paths.figureRoot = fullfile(cfg.paths.phaseResultRoot, 'figures');

cfg.paths.inphaseResultRoot = fullfile(cfg.paths.resultRoot, 'inphase');
cfg.paths.inphaseProcessedRoot = fullfile(cfg.paths.inphaseResultRoot, 'processed_data');
cfg.paths.inphaseFigureRoot = fullfile(cfg.paths.inphaseResultRoot, 'figures');

cfg.metadata.designsFile = fullfile(cfg.paths.metadataRoot, 'designs.csv');
cfg.metadata.devicesFile = fullfile(cfg.paths.metadataRoot, 'devices.csv');
cfg.metadata.scansFile = fullfile(cfg.paths.metadataRoot, 'scans.csv');
end
