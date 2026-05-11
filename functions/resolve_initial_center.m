function center0 = resolve_initial_center(cfg, scanCfg)
%RESOLVE_INITIAL_CENTER Resolve initial center from scanCfg or picked-center files.
%
% Priority:
%   1. scanCfg.centerInitial, if non-empty and finite;
%   2. batch picked center file:
%        local/initial_centers_batch_<batchName>.mat
%   3. legacy device picked center file:
%        local/initial_centers_<deviceName>.mat

if isfield(scanCfg, 'centerInitial') && ~isempty(scanCfg.centerInitial) && ...
        numel(scanCfg.centerInitial) == 2 && all(isfinite(scanCfg.centerInitial))
    center0 = scanCfg.centerInitial(:).';
    return;
end

% Batch center table.
if isfield(cfg, 'batchName')
    centerTable = load_batch_initial_centers(cfg);
    deviceID = string(getfield_or(scanCfg, 'deviceID', getfield_or(cfg, 'currentDeviceID', cfg.deviceName)));
    rawName = string(getfield_or(scanCfg, 'rawName', getfield_or(scanCfg, 'fileName', '')));
    [center0, found] = lookup_initial_center_from_table(centerTable, deviceID, scanCfg.scanID, rawName);
    if found
        return;
    end
end

% Legacy single-device center table.
localFile = fullfile(cfg.paths.projectRoot, 'local', ...
    sprintf('initial_centers_%s.mat', cfg.deviceName));

if isfile(localFile)
    S = load(localFile, 'centerTable');
    T = S.centerTable;

    row = T.scanID == scanCfg.scanID;

    if ~any(row)
        rawLabel = string(getfield_or(scanCfg, 'rawName', getfield_or(scanCfg, 'fileName', '')));
        if ismember('rawName', T.Properties.VariableNames)
            row = T.rawName == rawLabel;
        end
    end

    if any(row)
        idx = find(row, 1, 'first');
        center0 = [T.centerX_um(idx), T.centerY_um(idx)];
        return;
    end
end

error(['Initial center is not set for device %s scan %d.\n', ...
       'Run main_pick_initial_centers_for_batch first, or set centerX_um/centerY_um in scans metadata.'], ...
       cfg.deviceName, scanCfg.scanID);

end
