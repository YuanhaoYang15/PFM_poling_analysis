function fig = plot_batch_duty_notes(batchCfg, batchSummary)
%PLOT_BATCH_DUTY_NOTES Plot WG-region duty cycle with a right notes panel.
%
% Usage:
%   fig = plot_batch_duty_notes(batchCfg)
%   fig = plot_batch_duty_notes(batchCfg, batchSummary)
%
% The figure is intended for presentation/reporting:
%   left  : only the duty-cycle summary plot
%   right : scan index and device notes
%
% Optional config fields:
%   batchCfg.plot.dutyNotesYLim         = [0, 1];  % [] for auto
%   batchCfg.plot.dutyNotesReference    = 0.5;     % [] to disable
%   batchCfg.plot.dutyNotesXLabelMode   = 'index'; % 'index'/'raw'/'device'

batchCfg = set_default_batch_options(batchCfg);

if nargin < 2 || isempty(batchSummary)
    summaryFile = fullfile(batchCfg.paths.processedRoot, ...
        sprintf('batch_summary_%s.csv', batchCfg.batchName));

    if ~isfile(summaryFile)
        error('Batch summary not found:\n%s\nRun main_analyze_batch first.', summaryFile);
    end

    batchSummary = readtable(summaryFile, 'TextType', 'string');
end

visibleState = 'on';
if isfield(batchCfg, 'plot') && isfield(batchCfg.plot, 'showFigures') && ~batchCfg.plot.showFigures
    visibleState = 'off';
end

fig = figure('Color', 'w', 'Position', [120, 120, 1500, 720], ...
    'Visible', visibleState);
% Font sizes
axisFontSize  = get_optional_field(batchCfg, 'plot.dutyNotesAxisFontSize', 12);
labelFontSize = get_optional_field(batchCfg, 'plot.dutyNotesLabelFontSize', 14);
titleFontSize = get_optional_field(batchCfg, 'plot.dutyNotesTitleFontSize', 15);
noteFontSize  = get_optional_field(batchCfg, 'plot.dutyNotesNoteFontSize', 10);
sgFontSize    = get_optional_field(batchCfg, 'plot.dutyNotesSgTitleFontSize', 16);

n = height(batchSummary);
x = 1:n;

%% Main duty-cycle plot
ax = axes('Parent', fig, 'Position', [0.08, 0.16, 0.62, 0.72]);
hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
set(ax, 'FontSize', axisFontSize);

y = batchSummary.WG_duty_mean;

if ismember('WG_duty_std', batchSummary.Properties.VariableNames)
    yerr = batchSummary.WG_duty_std;
    errorbar(ax, x, y, yerr, 'o', ...
         'MarkerSize', 10, 'CapSize', 10,'LineWidth',2);
else
    plot(ax, x, y, 'o', 'MarkerSize', 10,'LineWidth',2);
end

refVal = get_optional_field(batchCfg, 'plot.dutyNotesReference', 0.5);
if ~isempty(refVal) && isfinite(refVal)
    yline(ax, refVal, 'k--', 'LineWidth', 1.0);
end

yl = get_optional_field(batchCfg, 'plot.dutyNotesYLim', [0, 1]);
if ~isempty(yl) && numel(yl) == 2 && all(isfinite(yl)) && yl(2) > yl(1)
    ylim(ax, yl);
end

xlim(ax, [0.5, n + 0.5]);
xticks(ax, x);

labelMode = string(get_optional_field(batchCfg, 'plot.dutyNotesXLabelMode', 'index'));
switch lower(labelMode)
    case "raw"
        if ismember('rawName', batchSummary.Properties.VariableNames)
            xticklabels(ax, string(batchSummary.rawName));
            xtickangle(ax, 45);
        end

    case "device"
        if ismember('deviceID', batchSummary.Properties.VariableNames) && ...
                ismember('scanID', batchSummary.Properties.VariableNames)
            labels = strings(n,1);
            for ii = 1:n
                labels(ii) = sprintf('%s-%d', ...
                    string(batchSummary.deviceID(ii)), double(batchSummary.scanID(ii)));
            end
            xticklabels(ax, labels);
            xtickangle(ax, 45);
        end

    otherwise
        % keep numeric scan index labels
end

xlabel(ax, 'scan index', 'FontSize', labelFontSize);
ylabel(ax, '<Duty> in WG region', 'FontSize', labelFontSize);
title(ax, 'WG-region mean duty cycle', ...
    'Interpreter', 'none', 'FontSize', titleFontSize);

%% Right notes panel
notesText = make_duty_notes_text(batchCfg, batchSummary);

axNote = axes('Parent', fig, 'Position', [0.74, 0.08, 0.23, 0.84]);
axis(axNote, 'off');
rectangle(axNote, 'Position', [0, 0, 1, 1], ...
    'FaceColor', [0.98, 0.98, 0.98], ...
    'EdgeColor', [0.75, 0.75, 0.75]);

text(axNote, 0.04, 0.97, notesText, ...
    'Units', 'normalized', ...
    'VerticalAlignment', 'top', ...
    'HorizontalAlignment', 'left', ...
    'FontName', 'Consolas', ...
    'FontSize', noteFontSize, ...
    'Interpreter', 'none');

sgtitle(fig, sprintf('Duty-cycle summary | %s', batchCfg.batchName), ...
    'FontWeight', 'bold', ...
    'Interpreter', 'none', ...
    'FontSize', sgFontSize);

end

function txt = make_duty_notes_text(batchCfg, batchSummary)
    lines = strings(0,1);

    lines(end+1) = "SCAN INDEX";
    lines(end+1) = "----------";

    for ii = 1:height(batchSummary)
        if ismember('rawName', batchSummary.Properties.VariableNames)
            rawName = string(batchSummary.rawName(ii));
        else
            rawName = "";
        end

        if strlength(rawName) > 0 && ~strcmpi(rawName, "nan")
            lines(end+1) = sprintf('%2d: %s', ii, rawName);
        else
            lines(end+1) = sprintf('%2d: %s-%d', ii, ...
                string(batchSummary.deviceID(ii)), double(batchSummary.scanID(ii)));
        end
    end

    lines(end+1) = "";
    lines(end+1) = "DEVICE NOTES";
    lines(end+1) = "------------";

    devices = table();
    try
        meta = read_batch_metadata(batchCfg);
        devices = meta.devices;
    catch
    end

    devIDs = unique(string(batchSummary.deviceID), 'stable');

    for ii = 1:numel(devIDs)
        devID = devIDs(ii);

        designID = "";
        rowText = "";
        colText = "";
        noteText = "";

        if ~isempty(devices) && ismember('deviceID', devices.Properties.VariableNames)
            row = devices(string(devices.deviceID) == devID, :);

            if ~isempty(row)
                designID = get_text(row, 'designID', '');
                rowVal = get_text(row, 'row', '');
                colVal = get_text(row, 'col', '');
                noteText = get_text(row, 'notes', '');

                if strlength(rowVal) > 0 && ~strcmpi(rowVal, "nan")
                    rowText = "r" + rowVal;
                end
                if strlength(colVal) > 0 && ~strcmpi(colVal, "nan")
                    colText = "c" + colVal;
                end
            end
        end

        if strlength(designID) == 0 || ismissing(designID)
            if ismember('designID', batchSummary.Properties.VariableNames)
                idx = find(string(batchSummary.deviceID) == devID, 1, 'first');
                designID = string(batchSummary.designID(idx));
            else
                designID = "";
            end
        end

        rcText = strjoin([rowText, colText], "");

        if strlength(rcText) > 0
            lines(end+1) = sprintf('%s | %s | %s', devID, designID, rcText);
        else
            lines(end+1) = sprintf('%s | %s', devID, designID);
        end

        if strlength(noteText) > 0 && ~strcmpi(noteText, "nan")
            wrapped = wrap_note(noteText, 34);
            for kk = 1:numel(wrapped)
                lines(end+1) = "  " + wrapped(kk);
            end
        else
            lines(end+1) = "  note: -";
        end
    end

    txt = strjoin(lines, newline);
end

function txt = get_text(Trow, varName, defaultVal)
    txt = string(defaultVal);

    if ~ismember(varName, Trow.Properties.VariableNames)
        return;
    end

    raw = Trow.(varName);

    if iscell(raw)
        raw = raw{1};
    end

    if ismissing(raw)
        txt = string(defaultVal);
    elseif isstring(raw)
        txt = raw(1);
    elseif ischar(raw)
        txt = string(raw);
    elseif isnumeric(raw)
        if isempty(raw) || ~isfinite(raw(1))
            txt = string(defaultVal);
        else
            txt = string(raw(1));
        end
    else
        txt = string(defaultVal);
    end

    if ismissing(txt)
        txt = string(defaultVal);
    end
end

function wrapped = wrap_note(noteText, maxLen)
    s = char(noteText);

    if numel(s) <= maxLen
        wrapped = string(s);
        return;
    end

    words = split(string(s));
    lines = strings(0,1);
    current = "";

    for ii = 1:numel(words)
        w = words(ii);

        if strlength(current) == 0
            current = w;
        elseif strlength(current) + 1 + strlength(w) <= maxLen
            current = current + " " + w;
        else
            lines(end+1) = current; %#ok<AGROW>
            current = w;
        end
    end

    if strlength(current) > 0
        lines(end+1) = current;
    end

    wrapped = lines;
end

function val = get_optional_field(S, path, defaultVal)
    parts = strsplit(path, '.');
    val = S;

    for ii = 1:numel(parts)
        if isstruct(val) && isfield(val, parts{ii})
            val = val.(parts{ii});
        else
            val = defaultVal;
            return;
        end
    end

    if isempty(val)
        val = defaultVal;
    end
end
