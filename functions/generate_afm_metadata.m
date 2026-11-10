function T = generate_afm_metadata(afmCfg)
%GENERATE_AFM_METADATA Scan the AFM raw folder and merge metadata/afm_scans.csv.
%
% Columns:
%   rawName, fileName, sample, gain, scanID, scanSizeX_um, scanSizeY_um,
%   nx, ny, expectedDepth_nm, include, notes
%
% Existing rows are preserved, so manual edits (notes, expectedDepth_nm,
% include) survive a metadata refresh. Only new raw files are appended.

afmCfg = set_default_afm_options(afmCfg);

rawRoot = afmCfg.paths.rawTxtRoot;
if ~isfolder(rawRoot)
    error('AFM raw folder does not exist: %s', rawRoot);
end

ext = afmCfg.afm.rawFileExt;
if ~startsWith(ext, '.')
    ext = ['.', ext];
end

fileList = dir(fullfile(rawRoot, ['*', ext]));

fprintf('\n========================================\n');
fprintf('Generate AFM metadata for batch: %s\n', afmCfg.batchName);
fprintf('Raw folder: %s\n', rawRoot);
fprintf('Raw extension: %s\n', ext);
fprintf('Found files: %d\n', numel(fileList));
fprintf('========================================\n\n');

canonicalCols = {'rawName', 'fileName', 'sample', 'gain', 'scanID', ...
    'scanSizeX_um', 'scanSizeY_um', 'nx', 'ny', ...
    'expectedDepth_nm', 'include', 'notes'};

newRows = table();
unmatched = strings(0, 1);
headerTokens = getfield_or(afmCfg.afm, 'headerTokens', {'Height_Sensor'});

for ii = 1:numel(fileList)
    [~, baseName, ~] = fileparts(fileList(ii).name);
    tok = regexp(baseName, afmCfg.afm.naming.pattern, 'names', 'once');

    if isempty(tok)
        unmatched(end + 1, 1) = string(fileList(ii).name); %#ok<AGROW>
        continue;
    end

    sample = "";
    if isfield(tok, 'sample')
        sample = string(tok.sample);
    end

    gain = NaN;
    if isfield(tok, 'gain')
        gain = str2double(strrep(tok.gain, 'p', '.'));
    end

    scanID = NaN;
    if isfield(tok, 'scanID')
        scanID = str2double(tok.scanID);
    end

    info = read_txt_header_info(fullfile(fileList(ii).folder, fileList(ii).name), ...
        headerTokens);

    row = table(string(baseName), string(fileList(ii).name), sample, gain, scanID, ...
        info.scanX_um, info.scanY_um, info.nx, info.ny, ...
        afmCfg.afm.expectedDepth_nm, true, "", ...
        'VariableNames', canonicalCols);

    if isempty(newRows)
        newRows = row;
    else
        newRows = [newRows; row]; %#ok<AGROW>
    end
end

fprintf('Matched files: %d\n', height(newRows));
fprintf('Unmatched files: %d\n', numel(unmatched));
if ~isempty(unmatched)
    fprintf('Unmatched files:\n');
    disp(unmatched);
end

metaFile = afmCfg.metadata.afmScansFile;
oldRows = read_table_if_exists(metaFile);
T = merge_scan_tables(oldRows, newRows, canonicalCols);

metaDir = fileparts(metaFile);
if ~exist(metaDir, 'dir')
    mkdir(metaDir);
end

for vv = 1:numel(T.Properties.VariableNames)
    if isstring(T.(vv))
        T.(vv)(ismissing(T.(vv))) = "";
    end
end
writetable(T, metaFile);

fprintf('\nAFM metadata written: %s\n', metaFile);
fprintf('Scans: %d\n', height(T));
fprintf('Edit expectedDepth_nm / include / notes in this CSV before analysis.\n');

end

function info = read_txt_header_info(filePath, headerTokens)
    info = struct('nx', NaN, 'ny', NaN, 'scanX_um', NaN, 'scanY_um', NaN, ...
        'headerLine', '');

    fid = fopen(filePath, 'r');
    if fid < 0
        warning('Cannot open AFM file for header info: %s', filePath);
        return;
    end
    cleanup = onCleanup(@() fclose(fid));

    while true
        line = fgetl(fid);
        if ~ischar(line)
            break;
        end

        tok = regexp(line, 'Samps/line:\s*([0-9]+)', 'tokens', 'once');
        if ~isempty(tok); info.nx = str2double(tok{1}); end

        tok = regexp(line, 'Number of lines:\s*([0-9]+)', 'tokens', 'once');
        if ~isempty(tok); info.ny = str2double(tok{1}); end

        tok = regexp(line, 'Scan Size:\s*([0-9.+\-eE]+)\s+([0-9.+\-eE]+)\s*(~?m|um|µm)?', ...
            'tokens', 'once');
        if ~isempty(tok)
            info.scanX_um = str2double(tok{1});
            info.scanY_um = str2double(tok{2});
        end

        tok = regexp(line, 'Scan Size:\s*([0-9.+\-eE]+)\s*nm', 'tokens', 'once');
        if ~isempty(tok) && isnan(info.scanX_um)
            info.scanX_um = str2double(tok{1}) / 1000;
            info.scanY_um = str2double(tok{1}) / 1000;
        end

        if ~contains(line, '@')
            isHeader = true;
            for tt = 1:numel(headerTokens)
                isHeader = isHeader && contains(line, headerTokens{tt});
            end
            if isHeader
                info.headerLine = line;
                break;
            end
        end
    end
end

function T = read_table_if_exists(filePath)
    if isfile(filePath)
        T = readtable(filePath, 'TextType', 'string');
    else
        T = table();
    end
end

function T = merge_scan_tables(oldT, newT, canonicalCols)
    if isempty(oldT) || height(oldT) == 0
        T = newT;
        return;
    end

    for ii = 1:numel(canonicalCols)
        if ~ismember(canonicalCols{ii}, oldT.Properties.VariableNames)
            oldT.(canonicalCols{ii}) = repmat(default_like(newT.(canonicalCols{ii})), ...
                height(oldT), 1);
        end
    end

    oldVars = oldT.Properties.VariableNames;
    for ii = 1:numel(oldVars)
        if ~ismember(oldVars{ii}, newT.Properties.VariableNames)
            newT.(oldVars{ii}) = repmat(default_like(oldT.(oldVars{ii})), ...
                height(newT), 1);
        end
    end
    newT = newT(:, oldVars);

    T = oldT;
    T.rawName = string(T.rawName);
    newT.rawName = string(newT.rawName);

    % Refresh auto-derived columns from the raw files; keep manual columns
    % (expectedDepth_nm, include, notes, and any extra user columns).
    autoCols = {'fileName', 'sample', 'gain', 'scanID', ...
        'scanSizeX_um', 'scanSizeY_um', 'nx', 'ny'};

    for ii = 1:height(newT)
        idx = find(T.rawName == newT.rawName(ii), 1, 'first');
        if isempty(idx)
            T = [T; newT(ii, :)]; %#ok<AGROW>
        else
            for cc = 1:numel(autoCols)
                T.(autoCols{cc})(idx) = newT.(autoCols{cc})(ii);
            end
        end
    end
end

function value = default_like(column)
    if isnumeric(column)
        value = NaN;
    elseif islogical(column)
        value = false;
    elseif iscell(column)
        value = {''};
    else
        value = "";
    end
end
