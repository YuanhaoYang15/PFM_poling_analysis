function S = set_nested_field(S, fieldPath, value)
%SET_NESTED_FIELD Set S.a.b.c = value.
parts = strsplit(fieldPath, '.');
if numel(parts) == 1
    S.(parts{1}) = value;
else
    p = parts{1};
    if ~isfield(S, p) || ~isstruct(S.(p))
        S.(p) = struct();
    end
    S.(p) = set_nested_field(S.(p), strjoin(parts(2:end), '.'), value);
end
end
