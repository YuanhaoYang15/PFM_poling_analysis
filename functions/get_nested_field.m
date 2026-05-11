function value = get_nested_field(S, fieldPath, defaultValue)
%GET_NESTED_FIELD Return S.a.b.c if it exists, otherwise defaultValue.
parts = strsplit(fieldPath, '.');
value = S;
for ii = 1:numel(parts)
    if isstruct(value) && isfield(value, parts{ii})
        value = value.(parts{ii});
    else
        value = defaultValue;
        return;
    end
end
if isempty(value)
    value = defaultValue;
end
end
