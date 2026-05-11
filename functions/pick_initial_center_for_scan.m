function center = pick_initial_center_for_scan(data, cfg, scanCfg, initialGuess)
%PICK_INITIAL_CENTER_FOR_SCAN Manually determine approximate device center.
%
% Default method:
%   manual_radial_lines
%
% This is adapted from the old working script. Instead of clicking one
% approximate center point, click two points on each radial domain line.
% The center is obtained from the least-squares intersection of all selected
% radial lines.
%
% Supported methods:
%   'manual_radial_lines' : click 2 points on each radial domain line
%   'manual_circle'       : click points along one circular boundary
%   'manual_point'        : click one approximate center point
%
% Configure with:
%   cfg.centerPicker.method = 'manual_radial_lines';

if nargin < 4
    initialGuess = [];
end

method = 'manual_radial_lines';
if isfield(cfg, 'centerPicker') && isfield(cfg.centerPicker, 'method') && ...
        ~isempty(cfg.centerPicker.method)
    method = cfg.centerPicker.method;
end

rawLabel = getfield_or(scanCfg, 'rawName', getfield_or(scanCfg, 'fileName', ''));

switch lower(method)
    case 'manual_radial_lines'
        [center, accepted] = pick_center_by_radial_lines(data, cfg, scanCfg, rawLabel, initialGuess);
    case 'manual_circle'
        [center, accepted] = pick_center_by_circle(data, cfg, scanCfg, rawLabel, initialGuess);
    case 'manual_point'
        [center, accepted] = pick_center_by_single_point(data, cfg, scanCfg, rawLabel, initialGuess);
    otherwise
        error('Unknown cfg.centerPicker.method: %s', method);
end

if ~accepted
    error('Center picking was cancelled by user.');
end

end

function [center, accepted] = pick_center_by_radial_lines(data, cfg, scanCfg, rawLabel, initialGuess)
    accepted = false;
    center = [NaN, NaN];

    while ~accepted
        fig = figure('Color','w','Position',[100 100 850 720]);
        show_phase_image(data, cfg);
        title({sprintf('Pick center by radial domain lines | scan %d | %s', ...
              scanCfg.scanID, rawLabel), ...
              'Click TWO points on each radial domain line. Use 5-10 lines if possible. Press Enter when finished.'}, ...
              'Interpreter','none');
        hold on;

        if ~isempty(initialGuess)
            plot(initialGuess(1), initialGuess(2), 'yo', 'MarkerSize', 10, 'LineWidth', 1.5);
            text(initialGuess(1), initialGuess(2), '  previous/current guess', ...
                'Color', 'y', 'FontWeight', 'bold', 'Interpreter', 'none');
        end

        fprintf('\nScan %d: radial-line center picking\n', scanCfg.scanID);
        fprintf('Click TWO points on each radial domain line.\n');
        fprintf('Use several lines with different angles, ideally 5-10.\n');
        fprintf('Press Enter when finished.\n\n');

        lineData = struct('n', {}, 'c', {});
        kline = 0;

        while true
            [xp, yp] = ginput(2);
            if numel(xp) < 2
                break;
            end

            p1 = [xp(1), yp(1)];
            p2 = [xp(2), yp(2)];

            d = p2 - p1;
            if norm(d) <= 0
                continue;
            end
            d = d / norm(d);

            n = [-d(2), d(1)];
            c = dot(n, p1);

            kline = kline + 1;
            lineData(kline).n = n; %#ok<AGROW>
            lineData(kline).c = c; %#ok<AGROW>

            plot([p1(1), p2(1)], [p1(2), p2(2)], 'w-', 'LineWidth', 1.5);
            plot(p1(1), p1(2), 'wo', 'MarkerFaceColor','w');
            plot(p2(1), p2(2), 'wo', 'MarkerFaceColor','w');
            text(mean([p1(1), p2(1)]), mean([p1(2), p2(2)]), sprintf('%d', kline), ...
                'Color', 'w', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        end

        if numel(lineData) < 2
            fprintf('Need at least two radial lines. Please try again.\n');
            close(fig);
            continue;
        end

        A = zeros(numel(lineData),2);
        b = zeros(numel(lineData),1);
        for k = 1:numel(lineData)
            A(k,:) = lineData(k).n;
            b(k)   = lineData(k).c;
        end

        center = (A \ b).';

        draw_center_overlay(center, cfg);
        fprintf('Fitted center from %d radial lines: [%.6f, %.6f] um\n', ...
            numel(lineData), center(1), center(2));

        answer = input('Accept this center? [Y]/n/r(retry)/c(cancel): ', 's');
        if isempty(answer) || any(strcmpi(answer, {'y','yes'}))
            accepted = true;
        elseif any(strcmpi(answer, {'c','cancel','q','quit'}))
            accepted = false;
            return;
        else
            close(fig);
            accepted = false;
        end
    end
end

function [center, accepted] = pick_center_by_circle(data, cfg, scanCfg, rawLabel, initialGuess)
    accepted = false;
    center = [NaN, NaN];

    while ~accepted
        fig = figure('Color','w','Position',[100 100 850 720]);
        show_phase_image(data, cfg);
        title({sprintf('Pick center by circle boundary | scan %d | %s', ...
              scanCfg.scanID, rawLabel), ...
              'Click points along one circular boundary. Use at least 5 points. Press Enter when finished.'}, ...
              'Interpreter','none');
        hold on;

        if ~isempty(initialGuess)
            plot(initialGuess(1), initialGuess(2), 'yo', 'MarkerSize', 10, 'LineWidth', 1.5);
        end

        [xp, yp] = ginput();

        if numel(xp) < 3
            fprintf('At least 3 points are required. Please try again.\n');
            close(fig);
            continue;
        end

        A = [2*xp(:), 2*yp(:), ones(numel(xp),1)];
        rhs = xp(:).^2 + yp(:).^2;
        sol = A \ rhs;

        center = [sol(1), sol(2)];

        plot(xp, yp, 'wo', 'MarkerFaceColor', 'w');
        draw_center_overlay(center, cfg);

        fprintf('Fitted center from circle points: [%.6f, %.6f] um\n', center(1), center(2));

        answer = input('Accept this center? [Y]/n/r(retry)/c(cancel): ', 's');
        if isempty(answer) || any(strcmpi(answer, {'y','yes'}))
            accepted = true;
        elseif any(strcmpi(answer, {'c','cancel','q','quit'}))
            accepted = false;
            return;
        else
            close(fig);
            accepted = false;
        end
    end
end

function [center, accepted] = pick_center_by_single_point(data, cfg, scanCfg, rawLabel, initialGuess)
    fig = figure('Color','w','Position',[100 100 850 720]);
    show_phase_image(data, cfg);
    title(sprintf('Click approximate center | scan %d | %s', scanCfg.scanID, rawLabel), ...
        'Interpreter', 'none');
    hold on;

    if ~isempty(initialGuess)
        plot(initialGuess(1), initialGuess(2), 'yo', 'MarkerSize', 10, 'LineWidth', 1.5);
    end

    fprintf('\nClick the approximate center once.\n');
    [xc, yc, button] = ginput(1);

    if isempty(button)
        if ~isempty(initialGuess)
            center = initialGuess;
        else
            accepted = false;
            center = [NaN, NaN];
            return;
        end
    else
        center = [xc, yc];
    end

    draw_center_overlay(center, cfg);

    answer = input('Accept this center? [Y]/n: ', 's');
    accepted = isempty(answer) || any(strcmpi(answer, {'y','yes'}));
end

function show_phase_image(data, cfg)
    imagesc(data.X(1,:), data.Y(:,1), data.phase);
    set(gca,'YDir','normal');
    axis image;
    colormap parula;
    colorbar;
    try
        caxis(cfg.plot.phaseCLim);
    catch
        caxis([-180 180]);
    end
    xlabel('x (\mum)');
    ylabel('y (\mum)');
end

function h = draw_center_overlay(center, cfg)
    theta = linspace(-pi, pi, 1000);

    rMin = cfg.radius.rMin;
    rMax = cfg.radius.rMax;
    wgMin = cfg.design.R0 - cfg.design.w/2;
    wgMax = cfg.design.R0 + cfg.design.w/2;

    h(1) = plot(center(1), center(2), 'rx', 'MarkerSize', 14, 'LineWidth', 2);
    h(2) = plot(center(1) + rMin*cos(theta), center(2) + rMin*sin(theta), ...
        'w-', 'LineWidth', 1.3);
    h(3) = plot(center(1) + rMax*cos(theta), center(2) + rMax*sin(theta), ...
        'm-', 'LineWidth', 1.3);
    h(4) = plot(center(1) + wgMin*cos(theta), center(2) + wgMin*sin(theta), ...
        '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 1.1);
    h(5) = plot(center(1) + wgMax*cos(theta), center(2) + wgMax*sin(theta), ...
        '-', 'Color', [0.8 0.8 0.8], 'LineWidth', 1.1);

    h(6) = text(center(1), center(2), ...
        sprintf('  center [%.3f, %.3f]', center(1), center(2)), ...
        'Color', 'r', 'FontWeight', 'bold', 'Interpreter', 'none');

    legend(h(1:5), {'fitted center', ...
        sprintf('rMin = %.2f um', rMin), sprintf('rMax = %.2f um', rMax), ...
        sprintf('WG inner = %.2f um', wgMin), sprintf('WG outer = %.2f um', wgMax)}, ...
        'Location', 'best', 'Interpreter', 'none');
end
