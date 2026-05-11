function [result, loaded] = load_processed_scan_result(cfg, scanCfg)
%LOAD_PROCESSED_SCAN_RESULT Load existing processed result if available.
paths = scan_result_paths(cfg, scanCfg);
loaded = false;
result = struct();
if isfile(paths.mat)
    S = load(paths.mat, 'result');
    if isfield(S, 'result')
        result = S.result;
        loaded = true;
    end
end
end
