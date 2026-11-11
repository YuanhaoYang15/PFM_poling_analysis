function [center, found, source] = find_initial_center(cfg, scanCfg)
%FIND_INITIAL_CENTER Look up a finite center without requiring a picked center.

found = false;
source = '';
if isfield(scanCfg, 'centerInitial') && numel(scanCfg.centerInitial) == 2 && ...
        all(isfinite(scanCfg.centerInitial(:)))
    center = scanCfg.centerInitial(:).';
    found = true;
    source = 'scans.csv';
    return;
end

if isfield(cfg, 'batchName')
    centerTable = load_batch_initial_centers(cfg);
    deviceID = string(getfield_or(scanCfg, 'deviceID', ...
        getfield_or(cfg, 'currentDeviceID', cfg.deviceName)));
    rawName = string(getfield_or(scanCfg, 'rawName', getfield_or(scanCfg, 'fileName', '')));
    [center, found] = lookup_initial_center_from_table(centerTable, deviceID, scanCfg.scanID, rawName);
    if found
        source = 'batch';
        return;
    end
end

localFile = fullfile(cfg.paths.projectRoot, 'local', ...
    sprintf('initial_centers_%s.mat', cfg.deviceName));
if isfile(localFile)
    S = load(localFile, 'centerTable');
    T = S.centerTable;
    row = T.scanID == scanCfg.scanID;
    if ~any(row) && ismember('rawName', T.Properties.VariableNames)
        rawLabel = string(getfield_or(scanCfg, 'rawName', getfield_or(scanCfg, 'fileName', '')));
        row = string(T.rawName) == rawLabel;
    end
    if any(row)
        idx = find(row, 1, 'first');
        candidate = [T.centerX_um(idx), T.centerY_um(idx)];
        if all(isfinite(candidate))
            center = candidate;
            found = true;
            source = 'legacy';
            return;
        end
    end
end
center = [];
end
