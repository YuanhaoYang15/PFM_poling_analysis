%% Plot duty-cycle-only batch summary with notes panel
%
% This script reads the active batch summary and generates a compact figure:
%   left  : WG-region mean duty cycle vs scan index
%   right : scan index + device notes
%
% Typical workflow:
%   main_analyze_batch
%   main_plot_batch_duty_notes

clear; clc; close all;

addpath(genpath(fullfile(pwd, 'functions')));
addpath(fullfile(pwd, 'config'));

batchCfg = get_active_batch_config();
batchCfg = set_default_batch_options(batchCfg);

% =========================
% User-adjustable options
% =========================
% Set to [] for automatic ylim.
batchCfg.plot.dutyNotesYLim = [0.25, 0.75];
batchCfg.plot.dutyNotesAxisFontSize = 15;
batchCfg.plot.dutyNotesLabelFontSize = 15;
batchCfg.plot.dutyNotesTitleFontSize = 15;
batchCfg.plot.dutyNotesNoteFontSize = 15;
batchCfg.plot.dutyNotesSgTitleFontSize = 15;

% Optional horizontal reference line. Set to [] to disable.
batchCfg.plot.dutyNotesReference = 0.5;

% Show scan labels on x axis:
%   'index'  -> 1,2,3,...
%   'raw'    -> rawName
%   'device' -> deviceID-scanID
batchCfg.plot.dutyNotesXLabelMode = 'index';

% Figure behavior for this presentation plot.
batchCfg.plot.showFigures = true;
batchCfg.plot.closeAfterSave = false;

fig = plot_batch_duty_notes(batchCfg);

if batchCfg.plot.saveFigures
    if ~exist(batchCfg.paths.figureRoot, 'dir')
        mkdir(batchCfg.paths.figureRoot);
    end

    pngPath = fullfile(batchCfg.paths.figureRoot, ...
        sprintf('Batch_duty_notes_%s.png', batchCfg.batchName));

    save_analysis_figure(fig, pngPath, batchCfg);
end
