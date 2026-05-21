function paths = local_paths_template()
%LOCAL_PATHS_TEMPLATE Template for machine-specific local paths.
%
% Usage:
%   1. Copy this file to:
%        local_paths.m
%   2. Edit the paths below for your own computer.
%   3. local_paths.m is ignored by Git and should not be committed.
%
% This lets the code project stay clean while private batches can live
% inside local/batches or in an external private directory.

paths = struct();

projectRoot = fileparts(fileparts(mfilename('fullpath')));

% Default private batch tree:
%   local/batches/<batchName>/{raw,metadata,centers,results}
paths.batchParent = fullfile(projectRoot, 'local', 'batches');

% Optional special-case roots for batches stored elsewhere.
paths.batchRoots = struct();
% paths.batchRoots.batch_20260511 = 'D:\...\PFM_batches\20260511';

end
