function cfg = get_active_batch_config()
%GET_ACTIVE_BATCH_CONFIG Load local active batch config if available.
%
% If local/active_batch_config.m exists, use it.
% Otherwise fall back to config_batch_20260511().

projectRoot = pwd;
localDir = fullfile(projectRoot, 'local');

if exist(fullfile(localDir, 'active_batch_config.m'), 'file')
    addpath(localDir);
    cfg = active_batch_config();
else
    warning(['local/active_batch_config.m not found. ', ...
             'Using default config_batch_20260511().']);
    cfg = config_batch_20260511();
end

end
