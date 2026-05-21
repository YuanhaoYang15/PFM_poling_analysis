function paths = get_batch_center_paths(batchCfg)
%GET_BATCH_CENTER_PATHS Return batch-local picked-center paths.

centerRoot = batchCfg.paths.centerRoot;
baseName = sprintf('initial_centers_batch_%s', batchCfg.batchName);

paths = struct();
paths.root = centerRoot;
paths.mat = fullfile(centerRoot, [baseName, '.mat']);
paths.csv = fullfile(centerRoot, [baseName, '.csv']);
paths.snippet = fullfile(centerRoot, [baseName, '_snippet.m']);
end
