function data = load_afm_data(afmCfg, rawName)
%LOAD_AFM_DATA Load one AFM txt scan into a channel struct.
%
% Output:
%   data.X, data.Y   coordinate matrices in um
%   data.channels    struct of exported channel matrices
%   data.height      primary height matrix (afm.heightField)
%   data.crossCheck  cross-check height matrix (afm.crossCheckField) or []
%   data.info        image size and scan size
%   data.raw         raw numeric table and column names

rawRoot = afmCfg.paths.rawTxtRoot;
ext = afmCfg.afm.rawFileExt;
if ~startsWith(ext, '.')
    ext = ['.', ext];
end

filePath = fullfile(rawRoot, [char(rawName), ext]);
if ~isfile(filePath)
    error('AFM raw file not found: %s', filePath);
end

headerTokens = getfield_or(afmCfg.afm, 'headerTokens', {'Height_Sensor'});
[D, info, raw] = read_nanoscope_txt_channels(filePath, headerTokens);

x_um = linspace(0, info.scanX_um, info.nx);
y_um = linspace(0, info.scanY_um, info.ny);
[X, Y] = meshgrid(x_um, y_um);

heightField = resolve_channel_field(D, ...
    getfield_or(afmCfg.afm, 'heightField', 'Height_Sensor'));

crossCheckField = getfield_or(afmCfg.afm, 'crossCheckField', '');
crossCheck = [];
if ~isempty(crossCheckField)
    crossCheckField = resolve_channel_field(D, crossCheckField);
    crossCheck = D.(crossCheckField);
end

data = struct();
data.rawName = char(rawName);
data.sourceFile = filePath;
data.X = X;
data.Y = Y;
data.info = info;
data.channels = D;
data.raw = raw;
data.heightField = heightField;
data.height = D.(heightField);
data.crossCheckField = crossCheckField;
data.crossCheck = crossCheck;

end

function field = resolve_channel_field(D, requested)
    names = fieldnames(D);

    if isfield(D, requested)
        field = requested;
        return;
    end

    for ii = 1:numel(names)
        if strcmpi(names{ii}, requested)
            field = names{ii};
            return;
        end
    end

    req = regexprep(requested, '[^a-zA-Z0-9]', '');
    for ii = 1:numel(names)
        nm = regexprep(names{ii}, '[^a-zA-Z0-9]', '');
        if strcmpi(nm, req)
            field = names{ii};
            return;
        end
    end

    error('Channel "%s" not found. Available channels: %s', ...
        requested, strjoin(names, ', '));
end
