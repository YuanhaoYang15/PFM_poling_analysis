function [D, info, raw] = read_pfm_txt_nanoscope_legacy(fname, ~)
%READ_PFM_TXT_NANOSCOPE_LEGACY Read NanoScope ASCII txt using the proven legacy logic.
%
% This is a thin wrapper around read_nanoscope_txt_channels with the PFM
% header tokens. The PFM exports contain a data header line with both
% Height_Sensor and LS_PR channels.
%
% Output:
%   D    : struct containing all exported channels, e.g. D.LS_PR_Phase
%   info : image size and scan size information
%   raw  : raw numeric table and column names

headerTokens = {'Height_Sensor', 'LS_PR'};
[D, info, raw] = read_nanoscope_txt_channels(fname, headerTokens);

end
