function fig = plot_batch_summary(batchCfg, batchSummary)
%PLOT_BATCH_SUMMARY Plot compact batch-level summary with a right notes panel.
%
% Device notes are intentionally simple and read from:
%   metadata/devices_<batchName>.csv
%
% Expected device columns:
%   deviceID, designID, row, col, notes

batchCfg = set_default_batch_options(batchCfg);

visibleState = 'on';
if ~batchCfg.plot.showFigures
    visibleState = 'off';
end

fig = figure('Color', 'w', 'Position', [80, 80, 1650, 860], ...
    'Visible', visibleState);

n = height(batchSummary);
x = 1:n;

% Left plotting region: 2 x 2 axes.
ax1 = axes('Parent', fig, 'Position', [0.07, 0.58, 0.36, 0.32]);
hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on');
scatter(ax1, x, batchSummary.WG_period_mean_um, 40, 'filled');
xlabel(ax1, 'scan index');
ylabel(ax1, '<\Lambda> in WG region (\mum)');
title(ax1, 'WG-region mean period');
xlim(ax1, [0, n+1]);

ax2 = axes('Parent', fig, 'Position', [0.50, 0.58, 0.26, 0.32]);
hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on');
scatter(ax2, x, batchSummary.WG_period_error_um, 40, 'filled');
yline(ax2, 0, 'k--');
xlabel(ax2, 'scan index');
ylabel(ax2, 'period error (\mum)');
title(ax2, 'Period error relative to design at R_0');
xlim(ax2, [0, n+1]);
ylim(ax2, [-batchCfg.plot.periodErrorYLimHalfRange, batchCfg.plot.periodErrorYLimHalfRange]);

ax3 = axes('Parent', fig, 'Position', [0.07, 0.13, 0.36, 0.32]);
hold(ax3, 'on'); grid(ax3, 'on'); box(ax3, 'on');
scatter(ax3, x, batchSummary.WG_duty_mean, 40, 'filled');
yline(ax3, 0.5, 'k--');
xlabel(ax3, 'scan index');
ylabel(ax3, '<Duty> in WG region');
ylim(ax3, [0, 1]);
title(ax3, 'WG-region mean duty cycle');
xlim(ax3, [0, n+1]);

ax4 = axes('Parent', fig, 'Position', [0.50, 0.13, 0.26, 0.32]);
hold(ax4, 'on'); grid(ax4, 'on'); box(ax4, 'on');
scatter(ax4, x, batchSummary.centerShiftAbs_um, 40, 'filled');
xlabel(ax4, 'scan index');
ylabel(ax4, '|center shift| (\mum)');
title(ax4, 'Center correction magnitude');
xlim(ax4, [0, n+1]);

% Right notes panel.
notesText = make_batch_notes_text(batchCfg, batchSummary);

axNote = axes('Parent', fig, 'Position', [0.80, 0.08, 0.18, 0.82]);
axis(axNote, 'off');
rectangle(axNote, 'Position', [0, 0, 1, 1], ...
    'FaceColor', [0.98, 0.98, 0.98], ...
    'EdgeColor', [0.75, 0.75, 0.75]);
text(axNote, 0.04, 0.97, notesText, ...
    'Units', 'normalized', ...
    'VerticalAlignment', 'top', ...
    'HorizontalAlignment', 'left', ...
    'FontName', 'Consolas', ...
    'FontSize', 9, ...
    'Interpreter', 'none');

sgtitle(fig, sprintf('Batch summary | %s', batchCfg.batchName), ...
    'FontWeight', 'bold', 'Interpreter', 'none');

end

function txt = make_batch_notes_text(batchCfg, batchSummary)
    lines = strings(0,1);

    lines(end+1) = "SCAN INDEX";
    lines(end+1) = "----------";

    for ii = 1:height(batchSummary)
        lines(end+1) = sprintf('%2d: %s-%d', ii, ...
            string(batchSummary.deviceID(ii)), double(batchSummary.scanID(ii)));
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
            idx = find(string(batchSummary.deviceID) == devID, 1, 'first');
            designID = string(batchSummary.designID(idx));
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
