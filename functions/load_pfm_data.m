function data = load_pfm_data(cfg, scanCfg)
%LOAD_PFM_DATA Load PFM phase data.
%
% This function accepts:
%   1. raw txt-export folders under cfg.paths.rawTxtRoot;
%   2. single txt/csv/dat files;
%   3. single mat files.
%
% If the input is a raw folder or txt file, preprocessing is done here.
% A preprocessed cache is saved automatically if cfg.preprocess.useCache = true.

rawName = getfield_or(scanCfg, 'rawName', getfield_or(scanCfg, 'fileName', ''));
if isempty(rawName)
    error('scanCfg must contain rawName or fileName.');
end

sourcePath = resolve_scan_source(cfg, rawName);

cacheDir = fullfile(cfg.paths.processedData, cfg.preprocess.cacheFolderName);
if ~exist(cacheDir, 'dir'); mkdir(cacheDir); end

safeName = regexprep(rawName, '[\\/:\*\?"<>\| ]', '_');
cacheFile = fullfile(cacheDir, [safeName, '_preprocessed.mat']);

if cfg.preprocess.enable && cfg.preprocess.useCache && isfile(cacheFile)
    tmp = load(cacheFile, 'data');
    data = tmp.data;
    fprintf('Loaded preprocessed cache: %s\n', cacheFile);
    return;
end

if isfolder(sourcePath)
    data = preprocess_pfm_raw_folder(sourcePath, cfg, scanCfg);
else
    [~, ~, ext] = fileparts(sourcePath);
    ext = lower(ext);

    switch ext
        case '.mat'
            data = load_pfm_mat_file(sourcePath, cfg);

        case {'.txt', '.csv', '.dat'}
            data = preprocess_pfm_text_file(sourcePath, cfg);

        otherwise
            error('Unsupported scan source extension: %s', ext);
    end
end

data.rawName = rawName;

if cfg.preprocess.enable && cfg.preprocess.useCache
    save(cacheFile, 'data', '-v7.3');
    fprintf('Saved preprocessed cache: %s\n', cacheFile);
end

end

function sourcePath = resolve_scan_source(cfg, rawName)
    candidates = {};

    % Absolute path
    if isfolder(rawName) || isfile(rawName)
        sourcePath = rawName;
        return;
    end

    roots = {};
    if isfield(cfg.paths, 'rawTxtRoot'); roots{end+1} = cfg.paths.rawTxtRoot; end
    if isfield(cfg.paths, 'rawData'); roots{end+1} = cfg.paths.rawData; end

    for rr = 1:numel(roots)
        root = roots{rr};
        candidates{end+1} = fullfile(root, rawName); %#ok<AGROW>
        [~,~,ext] = fileparts(rawName);
        if isempty(ext)
            for e = {'.txt', '.csv', '.dat', '.mat'}
                candidates{end+1} = fullfile(root, [rawName, e{1}]); %#ok<AGROW>
            end
        end
    end

    for ii = 1:numel(candidates)
        if isfolder(candidates{ii}) || isfile(candidates{ii})
            sourcePath = candidates{ii};
            return;
        end
    end

    fprintf('Tried these paths:\n');
    for ii = 1:numel(candidates)
        fprintf('  %s\n', candidates{ii});
    end
    error('Cannot find scan source: %s', rawName);
end

function data = load_pfm_mat_file(filePath, cfg)
    S = load(filePath);
    [X, Y, phase] = load_from_mat_struct_local(S, cfg);

    phase = convert_and_wrap_phase(phase, cfg);

    data = struct();
    data.X = X;
    data.Y = Y;
    data.phase = phase;
    data.sourceFile = filePath;
    data.sourceType = 'mat';
end

function [X, Y, phase] = load_from_mat_struct_local(S, cfg)
    names = fieldnames(S);

    if isfield(cfg, 'load') && ~isempty(cfg.load.phaseVar) && isfield(S, cfg.load.phaseVar)
        phase = S.(cfg.load.phaseVar);
    else
        phase = auto_find_phase_matrix(S, names);
    end

    if isfield(cfg, 'load') && ~isempty(cfg.load.xVar) && isfield(S, cfg.load.xVar)
        Xraw = S.(cfg.load.xVar);
    else
        Xraw = auto_find_axis(S, names, size(phase), 'x');
    end

    if isfield(cfg, 'load') && ~isempty(cfg.load.yVar) && isfield(S, cfg.load.yVar)
        Yraw = S.(cfg.load.yVar);
    else
        Yraw = auto_find_axis(S, names, size(phase), 'y');
    end

    [X, Y] = make_xy_grid_local(Xraw, Yraw, size(phase), cfg);
end

function phase = auto_find_phase_matrix(S, names)
    score = -inf(size(names));
    for ii = 1:numel(names)
        v = S.(names{ii});
        if isnumeric(v) && ismatrix(v) && numel(v) > 100
            score(ii) = 0;
            nm = lower(names{ii});
            if contains(nm, 'phase'); score(ii) = score(ii) + 10; end
            if contains(nm, 'pfm');   score(ii) = score(ii) + 5; end
            if contains(nm, 'pr');    score(ii) = score(ii) + 4; end
            if contains(nm, 'z');     score(ii) = score(ii) + 1; end
            score(ii) = score(ii) + log10(numel(v));
        end
    end
    [bestScore, idx] = max(score);
    if ~isfinite(bestScore)
        error('Cannot automatically find phase matrix in .mat file. Set cfg.load.phaseVar.');
    end
    phase = S.(names{idx});
end

function axisRaw = auto_find_axis(S, names, phaseSize, whichAxis)
    axisRaw = [];
    targetLen = phaseSize(2);
    if strcmpi(whichAxis, 'y')
        targetLen = phaseSize(1);
    end

    for ii = 1:numel(names)
        nm = lower(names{ii});
        v = S.(names{ii});
        if ~isnumeric(v); continue; end

        if strcmpi(whichAxis, 'x') && (strcmp(nm,'x') || contains(nm,'xaxis') || contains(nm,'x_um'))
            axisRaw = v; return;
        end
        if strcmpi(whichAxis, 'y') && (strcmp(nm,'y') || contains(nm,'yaxis') || contains(nm,'y_um'))
            axisRaw = v; return;
        end
    end

    for ii = 1:numel(names)
        v = S.(names{ii});
        if isnumeric(v) && isvector(v) && numel(v) == targetLen
            axisRaw = v; return;
        end
    end
end
