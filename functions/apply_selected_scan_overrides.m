function cfgScan = apply_selected_scan_overrides(cfgScan, selectedRow)
%APPLY_SELECTED_SCAN_OVERRIDES Apply optional per-scan override values.
%
% Optional columns:
%   centerSearchRange_um
%   centerSearchStep_um
%   fitRMin_um
%   fitRMax_um

if isempty(selectedRow) || height(selectedRow) == 0
    return;
end

v = get_optional_numeric(selectedRow, 'centerSearchRange_um');
if isfinite(v)
    cfgScan.centerOpt.searchRange = v;
end

v = get_optional_numeric(selectedRow, 'centerSearchStep_um');
if isfinite(v)
    cfgScan.centerOpt.searchStep = v;
end

fitMin = get_optional_numeric(selectedRow, 'fitRMin_um');
fitMax = get_optional_numeric(selectedRow, 'fitRMax_um');
if isfinite(fitMin) && isfinite(fitMax)
    cfgScan.centerOpt.fitRadiusRange = [fitMin, fitMax];
end

end

function v = get_optional_numeric(Trow, varName)
    v = NaN;
    if ~ismember(varName, Trow.Properties.VariableNames)
        return;
    end
    raw = Trow.(varName);
    if iscell(raw); raw = raw{1}; end
    if isstring(raw) || ischar(raw)
        v = str2double(raw);
    elseif isnumeric(raw) || islogical(raw)
        if ~isempty(raw); v = double(raw(1)); end
    end
end
