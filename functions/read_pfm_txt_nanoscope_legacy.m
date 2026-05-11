function [D, info, raw] = read_pfm_txt_nanoscope_legacy(fname, cfg)
%READ_PFM_TXT_NANOSCOPE_LEGACY Read NanoScope ASCII txt using the proven legacy logic.
%
% This is adapted from the old working script:
%   scan_pfm_duty_cycle_vs_radius_clean.m
%
% Output:
%   D    : struct containing all exported channels, e.g. D.LS_PR_Phase
%   info : image size and scan size information
%   raw  : raw numeric table and column names

if nargin < 2
    cfg = struct();
end

rawText = fileread(fname);
lines = regexp(rawText, '\r\n|\n|\r', 'split');

info = struct();
info.nx = [];
info.ny = [];
info.scanX_um = [];
info.scanY_um = [];

%% -------- Parse image size and scan size --------
for k = 1:numel(lines)
    line = lines{k};

    tok = regexp(line, 'Samps/line:\s*([0-9]+)', 'tokens', 'once');
    if ~isempty(tok)
        info.nx = str2double(tok{1});
    end

    tok = regexp(line, 'Number of lines:\s*([0-9]+)', 'tokens', 'once');
    if ~isempty(tok)
        info.ny = str2double(tok{1});
    end

    tok = regexp(line, 'Valid data len X:\s*([0-9]+)', 'tokens', 'once');
    if ~isempty(tok) && isempty(info.nx)
        info.nx = str2double(tok{1});
    end

    tok = regexp(line, 'Valid data len Y:\s*([0-9]+)', 'tokens', 'once');
    if ~isempty(tok) && isempty(info.ny)
        info.ny = str2double(tok{1});
    end

    % Case 1: Scan Size: 20 20 ~m / um / µm
    tok = regexp(line, 'Scan Size:\s*([0-9.+\-eE]+)\s+([0-9.+\-eE]+)\s*(~?m|um|µm)?', ...
        'tokens', 'once');

    if ~isempty(tok)
        sx = str2double(tok{1});
        sy = str2double(tok{2});

        info.scanX_um = sx;
        info.scanY_um = sy;
    end

    % Case 2: Scan Size: 20000 nm
    tok = regexp(line, 'Scan Size:\s*([0-9.+\-eE]+)\s*nm', ...
        'tokens', 'once');

    if ~isempty(tok) && isempty(info.scanX_um)
        s_nm = str2double(tok{1});
        info.scanX_um = s_nm / 1000;
        info.scanY_um = s_nm / 1000;
    end
end

if isempty(info.nx), info.nx = 256; end
if isempty(info.ny), info.ny = 256; end
if isempty(info.scanX_um), info.scanX_um = 20; end
if isempty(info.scanY_um), info.scanY_um = 20; end

%% -------- Find numeric data header --------
headerIdx = [];
for k = 1:numel(lines)
    line = strtrim(lines{k});

    isDataHeader = contains(line, 'Height_Sensor') && ...
                   contains(line, 'LS_PR') && ...
                   ~contains(line, '@') && ...
                   ~contains(line, '\@');

    if isDataHeader
        headerIdx = k;
        break;
    end
end

if isempty(headerIdx)
    error('Cannot find numeric data header line in file: %s', fname);
end

headerLine = strtrim(lines{headerIdx});
colTokens = regexp(headerLine, '\s+', 'split');
colTokens = colTokens(~cellfun(@isempty, colTokens));

nCol = numel(colTokens);

%% -------- Clean column names --------
colNames = cell(size(colTokens));

for j = 1:nCol
    name = colTokens{j};

    % Remove units such as (nm), (V), (°), ([]), etc.
    name = regexprep(name, '\([^\)]*\)', '');

    % Make a valid MATLAB field name
    name = regexprep(name, '[^a-zA-Z0-9_]', '_');
    name = matlab.lang.makeValidName(name);

    colNames{j} = name;
end

colNames = matlab.lang.makeUniqueStrings(colNames);

%% -------- Read numeric data --------
dataText = strjoin(lines(headerIdx+1:end), newline);

fmt = repmat('%f', 1, nCol);
C = textscan(dataText, fmt, ...
    'MultipleDelimsAsOne', true, ...
    'CollectOutput', true);

data = C{1};

nExpected = info.nx * info.ny;

if size(data,1) < nExpected
    error('Not enough numeric rows. Expected %d, found %d.', ...
        nExpected, size(data,1));
elseif size(data,1) > nExpected
    data = data(1:nExpected, :);
end

%% -------- Reshape each channel into image matrix --------
D = struct();

for j = 1:nCol
    D.(colNames{j}) = reshapeNanoScopeVector(data(:,j), info.nx, info.ny);
end

raw = struct();
raw.data = data;
raw.colTokens = colTokens;
raw.colNames = colNames;
raw.headerLine = headerLine;

fprintf('\nDetected columns:\n');
for j = 1:nCol
    fprintf('  %d: %-25s  ->  %s\n', j, colTokens{j}, colNames{j});
end
fprintf('\n');

fprintf('NanoScope legacy reader loaded:\n');
fprintf('  file: %s\n', fname);
fprintf('  image size: %d x %d pixels\n', info.nx, info.ny);
fprintf('  scan size: %.6g x %.6g um\n', info.scanX_um, info.scanY_um);

end

function Z = reshapeNanoScopeVector(v, nx, ny)
    Z = reshape(v, [nx, ny]).';
end
