function centerTable = load_batch_initial_centers(batchCfg)
%LOAD_BATCH_INITIAL_CENTERS Load picked center table for a batch.

centerPaths = get_batch_center_paths(batchCfg);
centerFile = centerPaths.mat;

if isfile(centerFile)
    S = load(centerFile, 'centerTable');
    centerTable = S.centerTable;
else
    centerTable = table();
end

end
