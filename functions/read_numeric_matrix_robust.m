function M = read_numeric_matrix_robust(filePath)
%READ_NUMERIC_MATRIX_ROBUST Read numeric content from a text file.
%
% First tries readmatrix. If that fails or returns empty, falls back to a
% line-by-line numeric parser.

try
    M = readmatrix(filePath, 'FileType', 'text');
    M = remove_empty_nan_borders(M);
    if ~isempty(M) && any(isfinite(M(:)))
        return;
    end
catch
end

% Fallback parser
fid = fopen(filePath, 'r');
if fid < 0
    error('Cannot open file: %s', filePath);
end

rows = {};
while true
    line = fgetl(fid);
    if ~ischar(line); break; end

    % Replace common delimiters by spaces.
    line = strrep(line, ',', ' ');
    line = strrep(line, ';', ' ');
    line = strrep(line, char(9), ' ');

    nums = sscanf(line, '%f').';
    if ~isempty(nums)
        rows{end+1} = nums; %#ok<AGROW>
    end
end
fclose(fid);

if isempty(rows)
    M = [];
    return;
end

maxLen = max(cellfun(@numel, rows));
M = nan(numel(rows), maxLen);
for ii = 1:numel(rows)
    M(ii, 1:numel(rows{ii})) = rows{ii};
end

M = remove_empty_nan_borders(M);

end
