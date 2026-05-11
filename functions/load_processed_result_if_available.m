function [result, found] = load_processed_result_if_available(cfgScan, scanID)
%LOAD_PROCESSED_RESULT_IF_AVAILABLE Load a saved scan result if present.

matPath = get_processed_result_path(cfgScan, scanID);

if isfile(matPath)
    S = load(matPath, 'result');
    if isfield(S, 'result')
        result = S.result;
        found = true;
        return;
    end
end

result = struct();
found = false;

end
