%% Simplify devices metadata for the active batch
%
% Converts:
%   deviceID,designID,polingGroup,polingVoltage,polingTime,row,col,notes
%
% to:
%   deviceID,designID,row,col,notes
%
% Existing notes are preserved. Poling columns are dropped.
% Write lab-format poling parameters directly in notes.

clear; clc;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
batchCfg = set_default_batch_options(batchCfg);

filePath = batchCfg.metadata.devicesFile;

if ~isfile(filePath)
    error('Devices metadata file not found:\n%s', filePath);
end

T = readtable(filePath, 'TextType', 'string');

required = {'deviceID','designID','row','col','notes'};

for ii = 1:numel(required)
    name = required{ii};
    if ~ismember(name, T.Properties.VariableNames)
        if strcmp(name, 'row') || strcmp(name, 'col')
            T.(name) = nan(height(T), 1);
        else
            T.(name) = strings(height(T), 1);
        end
    end
end

T.deviceID = string(T.deviceID);
T.designID = string(T.designID);
T.notes = string(T.notes);
T.notes(ismissing(T.notes)) = "";

% Infer missing row/col/designID from deviceID when possible.
for ii = 1:height(T)
    tok = regexp(T.deviceID(ii), '^(?<prefix>.+)_r(?<row>\d+)c(?<col>\d+)$', ...
        'names', 'once');

    if ~isempty(tok)
        if strlength(T.designID(ii)) == 0 || ismissing(T.designID(ii))
            T.designID(ii) = string(tok.prefix);
        end

        if ~isfinite(T.row(ii))
            T.row(ii) = str2double(tok.row);
        end

        if ~isfinite(T.col(ii))
            T.col(ii) = str2double(tok.col);
        end
    end
end

T = T(:, required);

writetable(T, filePath);

fprintf('Simplified devices metadata:\n  %s\n', filePath);
fprintf('Columns now are:\n');
disp(T.Properties.VariableNames);
