function generate_metadata_from_raw_folder(batchCfg)
%GENERATE_METADATA_FROM_RAW_FOLDER Generate/merge metadata CSVs from raw filenames.
%
% Device metadata is intentionally simple:
%   deviceID, designID, row, col, notes
%
% Poling conditions or lab-specific information should be written in notes.

batchCfg = set_default_batch_options(batchCfg);

rawRoot = batchCfg.paths.rawTxtRoot;
if ~isfolder(rawRoot)
    error('Raw txt root does not exist: %s', rawRoot);
end

ext = batchCfg.naming.rawFileExt;
if ~startsWith(ext, '.')
    ext = ['.', ext];
end

fileList = dir(fullfile(rawRoot, ['*', ext]));

fprintf('\n========================================\n');
fprintf('Generate metadata for batch: %s\n', batchCfg.batchName);
fprintf('Raw folder: %s\n', rawRoot);
fprintf('Raw extension: %s\n', ext);
fprintf('Found files: %d\n', numel(fileList));
fprintf('========================================\n\n');

newScans = table();
unmatched = strings(0,1);

for ii = 1:numel(fileList)
    [~, baseName, ~] = fileparts(fileList(ii).name);

    tok = regexp(baseName, batchCfg.naming.rawFilePattern, 'names', 'once');

    if isempty(tok)
        unmatched(end+1,1) = string(fileList(ii).name); %#ok<AGROW>
        continue;
    end

    prefix = string(tok.prefix);
    row = str2double(tok.row);
    col = str2double(tok.col);
    scanID = str2double(tok.scanID);

    deviceID = string(sprintf(batchCfg.naming.deviceIDFormat, prefix, row, col));

    T = table(deviceID, scanID, string(baseName), ...
        string(batchCfg.naming.defaultPhaseFilePattern), ...
        strings(1,1), NaN, NaN, strings(1,1), ...
        'VariableNames', { ...
        'deviceID','scanID','rawName','phaseFilePattern', ...
        'positionLabel','centerX_um','centerY_um','notes'});

    newScans = [newScans; T]; %#ok<AGROW>
end

fprintf('Matched files: %d\n', height(newScans));
fprintf('Unmatched files: %d\n', numel(unmatched));
if ~isempty(unmatched)
    fprintf('Unmatched files:\n');
    disp(unmatched);
end

oldScans  = read_table_if_exists(batchCfg.metadata.scansFile);
oldDevices = read_table_if_exists(batchCfg.metadata.devicesFile);
oldDesigns = read_table_if_exists(batchCfg.metadata.designsFile);

% Merge scans by rawName. Existing rows are preserved.
scans = merge_by_key(oldScans, newScans, 'rawName');

% Build simplified devices from scans, then merge with existing devices.
newDevices = build_devices_from_scans(scans, batchCfg);
oldDevices = simplify_devices_table(oldDevices, batchCfg);
devices = merge_devices_simplified(oldDevices, newDevices);

% Build missing design templates only. Existing design parameters are preserved.
newDesigns = build_designs_from_devices(devices);
designs = merge_by_key(oldDesigns, newDesigns, 'designID');

writetable(scans, batchCfg.metadata.scansFile);
writetable(devices, batchCfg.metadata.devicesFile);
writetable(designs, batchCfg.metadata.designsFile);

fprintf('\nMetadata updated:\n');
fprintf('  %s\n', batchCfg.metadata.scansFile);
fprintf('  %s\n', batchCfg.metadata.devicesFile);
fprintf('  %s\n', batchCfg.metadata.designsFile);
fprintf('\nDevice metadata columns are now simplified to:\n');
fprintf('  deviceID, designID, row, col, notes\n');
fprintf('Write lab-format poling parameters directly in notes.\n');

end

function T = read_table_if_exists(filePath)
    if isfile(filePath)
        T = readtable(filePath, 'TextType', 'string');
    else
        T = table();
    end
end

function out = merge_by_key(oldT, newT, keyName)
    if isempty(oldT) || height(oldT) == 0
        out = newT;
        return;
    end

    if isempty(newT) || height(newT) == 0
        out = oldT;
        return;
    end

    oldT.(keyName) = string(oldT.(keyName));
    newT.(keyName) = string(newT.(keyName));

    out = oldT;
    for ii = 1:height(newT)
        exists = out.(keyName) == newT.(keyName)(ii);
        if ~any(exists)
            out = [out; align_table_row(newT(ii,:), out)]; %#ok<AGROW>
        end
    end
end

function devices = build_devices_from_scans(scans, batchCfg)
    if isempty(scans) || height(scans) == 0
        devices = table();
        return;
    end

    devIDs = unique(string(scans.deviceID), 'stable');
    N = numel(devIDs);

    designID = strings(N,1);
    row = nan(N,1);
    col = nan(N,1);
    notes = strings(N,1);

    for ii = 1:N
        tok = regexp(devIDs(ii), '^(?<prefix>.+)_r(?<row>\d+)c(?<col>\d+)$', ...
            'names', 'once');

        if ~isempty(tok)
            if batchCfg.naming.designIDFromPrefix
                designID(ii) = string(tok.prefix);
            else
                designID(ii) = "DESIGN_A";
            end
            row(ii) = str2double(tok.row);
            col(ii) = str2double(tok.col);
        else
            designID(ii) = "DESIGN_A";
        end
    end

    devices = table(devIDs(:), designID, row, col, notes, ...
        'VariableNames', {'deviceID','designID','row','col','notes'});
end

function devices = simplify_devices_table(devicesIn, batchCfg)
    if isempty(devicesIn) || height(devicesIn) == 0
        devices = table();
        return;
    end

    N = height(devicesIn);

    deviceID = strings(N,1);
    designID = strings(N,1);
    row = nan(N,1);
    col = nan(N,1);
    notes = strings(N,1);

    if ismember('deviceID', devicesIn.Properties.VariableNames)
        deviceID = string(devicesIn.deviceID);
    end

    if ismember('designID', devicesIn.Properties.VariableNames)
        designID = string(devicesIn.designID);
    end

    if ismember('row', devicesIn.Properties.VariableNames)
        row = table_col_to_double(devicesIn.row);
    end

    if ismember('col', devicesIn.Properties.VariableNames)
        col = table_col_to_double(devicesIn.col);
    end

    if ismember('notes', devicesIn.Properties.VariableNames)
        notes = string(devicesIn.notes);
        notes(ismissing(notes)) = "";
    end

    % Fill missing designID/row/col from deviceID when possible.
    for ii = 1:N
        tok = regexp(deviceID(ii), '^(?<prefix>.+)_r(?<row>\d+)c(?<col>\d+)$', ...
            'names', 'once');

        if ~isempty(tok)
            if strlength(designID(ii)) == 0 || ismissing(designID(ii))
                if batchCfg.naming.designIDFromPrefix
                    designID(ii) = string(tok.prefix);
                else
                    designID(ii) = "DESIGN_A";
                end
            end
            if ~isfinite(row(ii)); row(ii) = str2double(tok.row); end
            if ~isfinite(col(ii)); col(ii) = str2double(tok.col); end
        end
    end

    devices = table(deviceID, designID, row, col, notes, ...
        'VariableNames', {'deviceID','designID','row','col','notes'});
end

function out = merge_devices_simplified(oldDevices, newDevices)
    if isempty(oldDevices) || height(oldDevices) == 0
        out = newDevices;
        return;
    end

    if isempty(newDevices) || height(newDevices) == 0
        out = oldDevices;
        return;
    end

    oldDevices.deviceID = string(oldDevices.deviceID);
    newDevices.deviceID = string(newDevices.deviceID);

    out = oldDevices;

    for ii = 1:height(newDevices)
        row = out.deviceID == newDevices.deviceID(ii);
        if any(row)
            idx = find(row, 1, 'first');

            % Preserve existing designID/row/col/notes if already filled.
            if strlength(string(out.designID(idx))) == 0 || ismissing(string(out.designID(idx)))
                out.designID(idx) = newDevices.designID(ii);
            end

            if ~isfinite(out.row(idx)); out.row(idx) = newDevices.row(ii); end
            if ~isfinite(out.col(idx)); out.col(idx) = newDevices.col(ii); end
        else
            out = [out; newDevices(ii,:)]; %#ok<AGROW>
        end
    end
end

function designs = build_designs_from_devices(devices)
    if isempty(devices) || height(devices) == 0
        designs = table();
        return;
    end

    designID = unique(string(devices.designID), 'stable');
    designID = designID(strlength(designID) > 0);

    N = numel(designID);

    designs = table(designID(:), ...
        30*ones(N,1), ones(N,1), 30*ones(N,1), 2.5*ones(N,1), ...
        28*ones(N,1), 35*ones(N,1), 0.1*ones(N,1), ...
        NaN(N,1), NaN(N,1), strings(N,1), ...
        'VariableNames', { ...
        'designID','R0_um','w_um','Rref_um','LambdaRef_um', ...
        'rMin_um','rMax_um','dr_um','scanSizeX_um','scanSizeY_um','notes'});
end

function row = align_table_row(row, targetTable)
    for vv = 1:numel(targetTable.Properties.VariableNames)
        name = targetTable.Properties.VariableNames{vv};

        if ~ismember(name, row.Properties.VariableNames)
            sample = targetTable.(name);
            if isnumeric(sample)
                row.(name) = NaN;
            elseif islogical(sample)
                row.(name) = false;
            elseif isstring(sample)
                row.(name) = strings(1,1);
            elseif iscell(sample)
                row.(name) = {''};
            else
                row.(name) = strings(1,1);
            end
        end
    end

    row = row(:, targetTable.Properties.VariableNames);
end

function v = table_col_to_double(x)
    if isnumeric(x)
        v = double(x);
    elseif isstring(x) || iscellstr(x) || ischar(x)
        v = str2double(string(x));
    else
        v = nan(size(x));
    end
end
