function value = getfield_or(S, fieldName, defaultValue)
%GETFIELD_OR Safe getfield with default value.

if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end

end
