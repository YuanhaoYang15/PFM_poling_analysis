function centerTable = load_batch_initial_centers(batchCfg)
%LOAD_BATCH_INITIAL_CENTERS Load picked center table for a batch.

centerFile = fullfile(batchCfg.paths.projectRoot, 'local', ...
    sprintf('initial_centers_batch_%s.mat', batchCfg.batchName));

if isfile(centerFile)
    S = load(centerFile, 'centerTable');
    centerTable = S.centerTable;
else
    centerTable = table();
end

end
