function summary = run_afm_batch_analysis(afmCfg)
%RUN_AFM_BATCH_ANALYSIS Analyze AFM scans: detect the waveguide angle, level
%the height using the far-field regions, slice perpendicular to the
%waveguide, and measure ridge-to-field / ridge-to-moat step heights.
%
% Outputs under local/batches/<batchName>/results/afm/:
%   processed_data/<rawName>_processed.mat
%   processed_data/afm_summary_<batchName>.csv
%   figures/<rawName>_summary.png
%   progress.log

afmCfg = set_default_afm_options(afmCfg);

processedRoot = afmCfg.paths.afmProcessedRoot;
figureRoot = afmCfg.paths.afmFigureRoot;
logFile = fullfile(afmCfg.paths.afmResultRoot, 'progress.log');
ensure_dir(processedRoot);
ensure_dir(figureRoot);
ensure_dir(afmCfg.paths.afmResultRoot);

metaFile = afmCfg.metadata.afmScansFile;
if ~isfile(metaFile)
    fprintf('AFM metadata not found. Generating: %s\n', metaFile);
    generate_afm_metadata(afmCfg);
end
scans = readtable(metaFile, 'TextType', 'string');

fprintf('\n========================================\n');
fprintf('AFM batch analysis\n');
fprintf('Batch: %s\n', afmCfg.batchName);
fprintf('Scans: %d\n', height(scans));
fprintf('Height channel: %s | cross-check: %s\n', ...
    afmCfg.afm.heightField, afmCfg.afm.crossCheckField);
fprintf('Leveling: %s | orientation: gradient histogram (p%d)\n', ...
    afmCfg.afm.level.method, afmCfg.afm.orientation.gradientPercentile);
fprintf('Output root: %s\n', afmCfg.paths.afmResultRoot);
fprintf('========================================\n\n');

log_line(logFile, sprintf('START AFM batch=%s scans=%d', ...
    afmCfg.batchName, height(scans)));

rows = repmat(empty_summary_row(), 0, 1);

for ii = 1:height(scans)
    scanRow = scans(ii, :);
    rawName = string(scanRow.rawName);

    if ~scan_included(scans, ii)
        fprintf('[%02d/%02d] %s | skipped (include=false)\n', ...
            ii, height(scans), rawName);
        continue;
    end

    fprintf('[%02d/%02d] %s | processing...\n', ii, height(scans), rawName);
    result = analyze_one_afm_scan(afmCfg, scanRow);

    matPath = fullfile(processedRoot, sprintf('%s_processed.mat', rawName));
    save(matPath, 'result', '-v7.3');

    if afmCfg.plot.saveFigures
        figPath = fullfile(figureRoot, sprintf('%s_summary.png', rawName));
        plot_afm_scan_summary(result, afmCfg, figPath);
        if getfield_or(afmCfg.plot, 'save3d', true)
            plot_afm_3d_surface(result, afmCfg, ...
                fullfile(figureRoot, sprintf('%s_3d.png', rawName)));
        end
        if getfield_or(afmCfg.plot, 'save3dTrueScale', true)
            plot_afm_3d_surface(result, afmCfg, ...
                fullfile(figureRoot, sprintf('%s_3d_true.png', rawName)), 1);
        end
    end

    row = summary_row_from_result(result);
    rows(end + 1, 1) = row; %#ok<AGROW>

    fprintf(['  waveguide = %.1f deg | slice = %.1f deg | ' ...
        'step L/R = %.1f / %.1f nm | moat L/R = %.1f / %.1f nm | ' ...
        'sidewall L/R = %.1f / %.1f deg | width = %.2f um | flag = %s\n'], ...
        result.orientation.waveguideAngle_deg, result.orientation.angle_deg, ...
        result.step.stepLeft_nm, result.step.stepRight_nm, ...
        result.step.stepMoatLeft_nm, result.step.stepMoatRight_nm, ...
        result.sidewall.leftMean_deg, result.sidewall.rightMean_deg, ...
        result.step.ridgeWidth_um, result.step.flag);
    log_line(logFile, sprintf(['DONE %s waveguide=%.1f slice=%.1f ' ...
        'stepL=%.1f stepR=%.1f moatL=%.1f moatR=%.1f sidewallL=%.1f ' ...
        'sidewallR=%.1f width=%.2f flag=%s'], ...
        rawName, result.orientation.waveguideAngle_deg, ...
        result.orientation.angle_deg, ...
        result.step.stepLeft_nm, result.step.stepRight_nm, ...
        result.step.stepMoatLeft_nm, result.step.stepMoatRight_nm, ...
        result.sidewall.leftMean_deg, result.sidewall.rightMean_deg, ...
        result.step.ridgeWidth_um, result.step.flag));
end

summary = struct2table(rows);
summaryPath = fullfile(processedRoot, ...
    sprintf('afm_summary_%s.csv', afmCfg.batchName));
writetable(summary, summaryPath);

fprintf('\nAFM analysis complete.\n');
fprintf('  Summary: %s\n', summaryPath);
fprintf('  Per-scan MAT: %s\n', processedRoot);
if afmCfg.plot.saveFigures
    fprintf('  Figures: %s\n', figureRoot);
end
log_line(logFile, sprintf('END AFM batch=%s scans=%d', ...
    afmCfg.batchName, height(summary)));

end

function result = analyze_one_afm_scan(afmCfg, scanRow)
    rawName = string(scanRow.rawName);
    data = load_afm_data(afmCfg, rawName);

    X = data.X;
    Y = data.Y;
    Zraw = data.height;

    % 1. Waveguide orientation.
    orient = detect_afm_waveguide_angle(Zraw, X, Y, afmCfg.afm.orientation);
    uMat = X * cosd(orient.angle_deg) + Y * sind(orient.angle_deg);

    % 2. Raw profile and structure masks (ridge, moats, far field).
    profRaw = extract_afm_profile(Zraw, X, Y, orient.angle_deg, afmCfg.afm.profile);
    ff = afm_farfield_mask(profRaw, uMat, afmCfg.afm.level);

    % 3. Leveling.
    switch lower(char(string(afmCfg.afm.level.method)))
        case 'farfield_plane'
            [Zlev, level] = level_afm_farfield(Zraw, X, Y, ff.mask, afmCfg.afm.level);
        case 'plane'
            [Zlev, level] = flatten_afm_height(Zraw, struct('method', 'plane'));
            level.ok = true;
            level.flag = "ok";
        case 'plane_line'
            [Zlev, level] = flatten_afm_height(Zraw, struct('method', 'plane_line'));
            level.ok = true;
            level.flag = "ok";
        case 'none'
            Zlev = Zraw;
            level = struct('ok', true, 'flag', "none", 'maskCount', NaN, ...
                'residualRms_nm', NaN);
        otherwise
            error('Unknown afm.level.method: %s', afmCfg.afm.level.method);
    end
    if ~isfield(level, 'maskCount'); level.maskCount = NaN; end
    if ~isfield(level, 'residualRms_nm'); level.residualRms_nm = NaN; end

    % 4. Leveled profile and step heights.
    prof = extract_afm_profile(Zlev, X, Y, orient.angle_deg, afmCfg.afm.profile);
    stepCfg = afmCfg.afm.plateau;
    stepCfg.leveling = getfield_or(afmCfg.afm.level, 'plateauLeveling', true);
    step = extract_afm_step(Zlev, X, Y, uMat, prof, ff, stepCfg);
    farQc = afm_farfield_qc(Zlev, prof, ff);
    sidewall = extract_afm_sidewall(Zlev, X, Y, uMat, prof, step, ff, ...
        afmCfg.afm.sidewall);

    % 5. Cross-check channel with the same geometry.
    xcheck = struct('field', "", 'step', empty_step_struct());
    if ~isempty(data.crossCheck)
        ZcLev = level_afm_farfield(data.crossCheck, X, Y, ff.mask, afmCfg.afm.level);
        profC = extract_afm_profile(ZcLev, X, Y, orient.angle_deg, afmCfg.afm.profile);
        stepC = extract_afm_step(ZcLev, X, Y, uMat, profC, ff, stepCfg);
        xcheck.field = string(data.crossCheckField);
        xcheck.step = stepC;
    end

    quality = afm_quality_metrics(Zraw, afmCfg.afm.quality);

    result = struct();
    result.rawName = char(rawName);
    result.sourceFile = data.sourceFile;
    result.sample = table_text_value(scanRow, 'sample');
    result.gain = table_number_value(scanRow, 'gain');
    result.scanID = table_number_value(scanRow, 'scanID');
    result.expectedDepth_nm = table_number_value(scanRow, 'expectedDepth_nm');
    result.notes = table_text_value(scanRow, 'notes');
    result.info = data.info;
    result.channels = fieldnames(data.channels);
    result.heightField = data.heightField;
    result.crossCheckField = data.crossCheckField;
    result.data = struct('X', X, 'Y', Y, 'heightRaw', Zraw, 'heightLevel', Zlev);
    result.orientation = orient;
    result.profileRaw = profRaw;
    result.profile = prof;
    result.farfield = ff;
    result.level = level;
    result.step = step;
    result.farQc = farQc;
    result.sidewall = sidewall;
    result.xcheck = xcheck;
    result.quality = quality;
    result.configUsed = afmCfg;
end

function qc = afm_farfield_qc(Z, prof, ff)
    coord = prof.coord_um(:).';
    vals = prof.values_nm(:).';
    qc = struct('slopeLeft_nm_per_um', NaN, 'slopeRight_nm_per_um', NaN, ...
        'rmsLeft_nm', NaN, 'rmsRight_nm', NaN);

    if isfinite(ff.uMoatLeft_um)
        m = coord < ff.uMoatLeft_um;
        if nnz(m & isfinite(vals)) >= 5
            p = polyfit(coord(m & isfinite(vals)), vals(m & isfinite(vals)), 1);
            qc.slopeLeft_nm_per_um = p(1);
        end
        z = Z(ff.leftMask);
        z = z(isfinite(z));
        if ~isempty(z)
            qc.rmsLeft_nm = std(z);
        end
    end

    if isfinite(ff.uMoatRight_um)
        m = coord > ff.uMoatRight_um;
        if nnz(m & isfinite(vals)) >= 5
            p = polyfit(coord(m & isfinite(vals)), vals(m & isfinite(vals)), 1);
            qc.slopeRight_nm_per_um = p(1);
        end
        z = Z(ff.rightMask);
        z = z(isfinite(z));
        if ~isempty(z)
            qc.rmsRight_nm = std(z);
        end
    end
end

function q = afm_quality_metrics(Z, cfg)
    threshold = getfield_or(cfg, 'rowJumpThreshold_nm', 15);
    rowMed = median(Z, 2, 'omitnan');
    d = abs(diff(rowMed));
    q = struct();
    q.rowJumpMax_nm = max(d);
    q.rowJumpCount = sum(d > threshold);
    q.threshold_nm = threshold;
    if q.rowJumpCount > 0
        q.flag = "row_jump";
    else
        q.flag = "ok";
    end
end

function row = summary_row_from_result(result)
    row = empty_summary_row();
    row.rawName = string(result.rawName);
    row.sample = result.sample;
    row.gain = result.gain;
    row.scanID = result.scanID;
    row.scanSizeX_um = result.info.scanX_um;
    row.nx = result.info.nx;
    row.ny = result.info.ny;
    row.angle_deg = result.orientation.angle_deg;
    row.waveguideAngle_deg = result.orientation.waveguideAngle_deg;
    row.ridgeLeft_um = result.step.leftEdge_um;
    row.ridgeRight_um = result.step.rightEdge_um;
    row.ridgeWidth_um = result.step.ridgeWidth_um;
    row.topLevel_nm = result.step.topLevel_nm;
    row.farLeft_nm = result.step.farLeft_nm;
    row.farRight_nm = result.step.farRight_nm;
    row.moatLeft_nm = result.step.moatLeft_nm;
    row.moatRight_nm = result.step.moatRight_nm;
    row.stepLeft_nm = result.step.stepLeft_nm;
    row.stepRight_nm = result.step.stepRight_nm;
    row.stepMean_nm = result.step.stepMean_nm;
    row.asymmetry_nm = result.step.asymmetry_nm;
    row.stepMoatLeft_nm = result.step.stepMoatLeft_nm;
    row.stepMoatRight_nm = result.step.stepMoatRight_nm;
    row.sidewallLeft_deg = result.sidewall.left_deg;
    row.sidewallRight_deg = result.sidewall.right_deg;
    row.sidewallLeftMean_deg = result.sidewall.leftMean_deg;
    row.sidewallLeftStd_deg = result.sidewall.leftStd_deg;
    row.sidewallRightMean_deg = result.sidewall.rightMean_deg;
    row.sidewallRightStd_deg = result.sidewall.rightStd_deg;
    row.ridgeTopWidth_um = result.sidewall.topWidth_um;
    row.ridgeBaseWidth_um = result.sidewall.baseWidth_um;
    row.topRq_nm = result.step.topRq_nm;
    row.farRms_nm = result.level.residualRms_nm;
    row.farSlopeLeft_nm_per_um = result.farQc.slopeLeft_nm_per_um;
    row.farSlopeRight_nm_per_um = result.farQc.slopeRight_nm_per_um;
    row.farPixels = result.level.maskCount;
    row.rowJumpMax_nm = result.quality.rowJumpMax_nm;
    row.rowJumpCount = result.quality.rowJumpCount;
    row.qualityFlag = result.quality.flag;
    row.stepFlag = result.step.flag;
    row.xcheckField = result.xcheck.field;
    row.xcheck_stepLeft_nm = result.xcheck.step.stepLeft_nm;
    row.xcheck_stepRight_nm = result.xcheck.step.stepRight_nm;
    row.expectedDepth_nm = result.expectedDepth_nm;
    if isfinite(result.expectedDepth_nm) && isfinite(result.step.stepMean_nm)
        row.depthError_nm = result.step.stepMean_nm - result.expectedDepth_nm;
    end
    row.notes = result.notes;
end

function row = empty_summary_row()
    row = struct( ...
        'rawName', "", ...
        'sample', "", ...
        'gain', NaN, ...
        'scanID', NaN, ...
        'scanSizeX_um', NaN, ...
        'nx', NaN, ...
        'ny', NaN, ...
        'angle_deg', NaN, ...
        'waveguideAngle_deg', NaN, ...
        'ridgeLeft_um', NaN, ...
        'ridgeRight_um', NaN, ...
        'ridgeWidth_um', NaN, ...
        'topLevel_nm', NaN, ...
        'farLeft_nm', NaN, ...
        'farRight_nm', NaN, ...
        'moatLeft_nm', NaN, ...
        'moatRight_nm', NaN, ...
        'stepLeft_nm', NaN, ...
        'stepRight_nm', NaN, ...
        'stepMean_nm', NaN, ...
        'asymmetry_nm', NaN, ...
        'stepMoatLeft_nm', NaN, ...
        'stepMoatRight_nm', NaN, ...
        'sidewallLeft_deg', NaN, ...
        'sidewallRight_deg', NaN, ...
        'sidewallLeftMean_deg', NaN, ...
        'sidewallLeftStd_deg', NaN, ...
        'sidewallRightMean_deg', NaN, ...
        'sidewallRightStd_deg', NaN, ...
        'ridgeTopWidth_um', NaN, ...
        'ridgeBaseWidth_um', NaN, ...
        'topRq_nm', NaN, ...
        'farRms_nm', NaN, ...
        'farSlopeLeft_nm_per_um', NaN, ...
        'farSlopeRight_nm_per_um', NaN, ...
        'farPixels', NaN, ...
        'rowJumpMax_nm', NaN, ...
        'rowJumpCount', NaN, ...
        'qualityFlag', "", ...
        'stepFlag', "", ...
        'xcheckField', "", ...
        'xcheck_stepLeft_nm', NaN, ...
        'xcheck_stepRight_nm', NaN, ...
        'expectedDepth_nm', NaN, ...
        'depthError_nm', NaN, ...
        'notes', "");
end

function step = empty_step_struct()
    step = struct( ...
        'angle_deg', NaN, ...
        'topLevel_nm', NaN, ...
        'farLeft_nm', NaN, ...
        'farRight_nm', NaN, ...
        'moatLeft_nm', NaN, ...
        'moatRight_nm', NaN, ...
        'stepLeft_nm', NaN, ...
        'stepRight_nm', NaN, ...
        'stepMean_nm', NaN, ...
        'asymmetry_nm', NaN, ...
        'stepMoatLeft_nm', NaN, ...
        'stepMoatRight_nm', NaN, ...
        'ridgeWidth_um', NaN, ...
        'flag', "");
end

function tf = scan_included(T, idx)
    if ~ismember('include', T.Properties.VariableNames)
        tf = true;
        return;
    end

    v = T.include(idx);
    if islogical(v) || isnumeric(v)
        tf = logical(v);
    else
        s = lower(string(v));
        tf = any(s == ["true", "1", "yes", "y"]);
    end
end

function value = table_text_value(T, name)
    if ismember(name, T.Properties.VariableNames)
        value = string(T.(name)(1));
    else
        value = "";
    end
end

function value = table_number_value(T, name)
    if ~ismember(name, T.Properties.VariableNames)
        value = NaN;
        return;
    end

    v = T.(name)(1);
    if isnumeric(v) || islogical(v)
        value = double(v);
    else
        value = str2double(strrep(string(v), 'p', '.'));
    end
end

function ensure_dir(pathValue)
    if ~exist(pathValue, 'dir')
        mkdir(pathValue);
    end
end

function log_line(logFile, message)
    stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    line = sprintf('[%s] %s', stamp, message);
    fid = fopen(logFile, 'a');
    if fid >= 0
        fprintf(fid, '%s\n', line);
        fclose(fid);
    end
    fprintf('%s\n', line);
end
