function cfg = active_batch_config()
%ACTIVE_BATCH_CONFIG Select which batch config to run.
%
% Usage:
%   1. Copy this file to:
%        active_batch_config.m
%   2. Edit the line below.
%   3. active_batch_config.m is ignored by Git.

cfg = config_batch_20260511();

% To switch to the other batch, use:
% cfg = config_batch_20260506();

end
