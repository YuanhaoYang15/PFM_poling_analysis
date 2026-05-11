function val = get_numeric_table_value(Trow, varName, defaultVal)
%GET_NUMERIC_TABLE_VALUE Safely get a numeric value from a table row.

if ~ismember(varName, Trow.Properties.VariableNames)
    val = defaultVal;
    return;
end

raw = Trow.(varName);

if istable(raw)
    raw = table2array(raw);
end

if iscell(raw)
    raw = raw{1};
end

if isstring(raw) || ischar(raw)
    val = str2double(raw);
elseif isnumeric(raw) || islogical(raw)
    val = double(raw(1));
else
    val = NaN;
end

if isempty(val) || ~isfinite(val)
    val = defaultVal;
end

end
