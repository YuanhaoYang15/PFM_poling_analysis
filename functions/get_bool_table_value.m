function val = get_bool_table_value(Trow, varName, defaultVal)
%GET_BOOL_TABLE_VALUE Safely get a logical value from a table row.
if ~ismember(varName, Trow.Properties.VariableNames)
    val = defaultVal;
    return;
end
raw = Trow.(varName);
if istable(raw); raw = table2array(raw); end
if iscell(raw); raw = raw{1}; end
if ismissing(raw)
    val = defaultVal;
elseif islogical(raw)
    val = raw(1);
elseif isnumeric(raw)
    val = isfinite(raw(1)) && raw(1) ~= 0;
else
    s = lower(strtrim(char(string(raw))));
    if any(strcmp(s, {'true','t','yes','y','1'}))
        val = true;
    elseif any(strcmp(s, {'false','f','no','n','0'}))
        val = false;
    else
        val = defaultVal;
    end
end
end
