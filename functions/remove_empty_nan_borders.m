function M = remove_empty_nan_borders(M)
%REMOVE_EMPTY_NAN_BORDERS Remove all-NaN rows/columns.

if isempty(M); return; end

M = double(M);

rowKeep = ~all(isnan(M), 2);
colKeep = ~all(isnan(M), 1);

M = M(rowKeep, colKeep);

end
