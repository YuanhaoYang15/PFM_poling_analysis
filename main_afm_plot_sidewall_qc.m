%% Plot sidewall angle QC figures for the active AFM batch
%
% For every included scan this writes:
%   <rawName>_sidewall_definition.png : angle definition on the profile
%   <rawName>_sidewall_vs_slice.png   : left/right angle per slice
%
% The per-scan MAT files are reused. If a MAT predates the sidewall fit
% details, the sidewall struct is recomputed from the saved leveled data.

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

afmCfg = get_active_afm_batch_config();
afmCfg = set_default_afm_options(afmCfg);

if ~isfile(afmCfg.metadata.afmScansFile)
    error('AFM metadata not found: %s', afmCfg.metadata.afmScansFile);
end
scans = readtable(afmCfg.metadata.afmScansFile, 'TextType', 'string');

for ii = 1:height(scans)
    rawName = string(scans.rawName(ii));
    if ismember('include', scans.Properties.VariableNames)
        inc = scans.include(ii);
        if (islogical(inc) || isnumeric(inc)) && ~logical(inc)
            continue;
        end
    end

    matFile = fullfile(afmCfg.paths.afmProcessedRoot, ...
        sprintf('%s_processed.mat', rawName));
    if ~isfile(matFile)
        warning('Skipping %s: processed MAT not found.', rawName);
        continue;
    end

    S = load(matFile);
    result = S.result;

    if ~isfield(result.sidewall, 'leftFit') || ~isfield(result.sidewall, 'sliceV_um')
        uMat = result.data.X * cosd(result.orientation.angle_deg) + ...
            result.data.Y * sind(result.orientation.angle_deg);
        result.sidewall = extract_afm_sidewall(result.data.heightLevel, ...
            result.data.X, result.data.Y, uMat, result.profile, ...
            result.step, result.farfield, afmCfg.afm.sidewall);
    end

    paths = plot_afm_sidewall_qc(result, afmCfg);
    fprintf('%s\n  %s\n', paths.definition, paths.vsSlice);
end
