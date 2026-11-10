function cfg = get_active_afm_batch_config()
%GET_ACTIVE_AFM_BATCH_CONFIG Load the local active AFM batch config.
%
% Requires local/active_afm_batch_config.m. Copy
% local/active_afm_batch_config_template.m to that file and select the
% AFM batch config to run.

projectRoot = pwd;
localDir = fullfile(projectRoot, 'local');

if exist(fullfile(localDir, 'active_afm_batch_config.m'), 'file')
    addpath(localDir);
    cfg = active_afm_batch_config();
else
    error(['local/active_afm_batch_config.m not found. Copy ', ...
        'local/active_afm_batch_config_template.m to ', ...
        'local/active_afm_batch_config.m and select an AFM config.']);
end

end
