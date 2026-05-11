function txt = get_text_table_value(Trow, varName, defaultVal)
%GET_TEXT_TABLE_VALUE Safely get text from a table row.
%
% Converts missing/empty table entries to defaultVal.

if ~ismember(varName, Trow.Properties.VariableNames)
    txt = defaultVal;
    return;
end

raw = Trow.(varName);

if istable(raw)
    raw = table2array(raw);
end

if iscell(raw)
    raw = raw{1};
end

if ismissing(raw)
    txt = defaultVal;
    return;
end

if isstring(raw)
    if strlength(raw) == 0 || ismissing(raw)
        txt = defaultVal;
    else
        txt = char(raw);
    end
elseif ischar(raw)
    if isempty(raw)
        txt = defaultVal;
    else
        txt = raw;
    end
elseif isnumeric(raw)
    if isempty(raw) || isnan(raw)
        txt = defaultVal;
    else
        txt = char(string(raw));
    end
else
    txt = defaultVal;
end

end