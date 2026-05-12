function analysis = extract_period_duty_vs_radius(data, center, rList, cfg)
%EXTRACT_PERIOD_DUTY_VS_RADIUS Extract period/duty versus radius.
%
% Stable extraction logic:
%   1. interpolate cos(phase) and sin(phase), not raw wrapped phase;
%   2. reconstruct wrapped phase along the arc;
%   3. smooth on the unit circle;
%   4. classify the two PFM phase states using 2D k-means;
%   5. compute period and duty cycle from the binary trace.
%
% New in this version:
%   Arc sampling and smoothing can be specified in physical units:
%
%       cfg.arc.ds_um                  arc-length sampling step
%       cfg.extract.phaseSmooth_um     phase smoothing length
%       cfg.extract.binarySmooth_um    binary smoothing length
%       cfg.extract.minSegment_um      minimum accepted segment length
%
% If these fields are absent or empty, the old point-count parameters are used:
%
%       cfg.arc.nTheta
%       cfg.extract.phaseSmoothWin
%       cfg.extract.binarySmoothWin
%       cfg.extract.minSegmentPts

phase_deg = data.phase;
x_um = data.X(1,:);
y_um = data.Y(:,1).';

xc_um = center(1);
yc_um = center(2);

nR = numel(rList);

arc = repmat(struct(), 1, nR);

periodMean = nan(1, nR);
periodStd  = nan(1, nR);
dutyMean   = nan(1, nR);
dutyStd    = nan(1, nR);
nPeriods   = nan(1, nR);

details = repmat(struct(), 1, nR);

% Old fallback parameters.
nThetaDefault = get_cfg_value(cfg, 'arc.nTheta', 6000);
phaseSmoothWinDefault = get_cfg_value(cfg, 'extract.phaseSmoothWin', ...
                         get_cfg_value(cfg, 'extract.smoothWindow', 9));
binarySmoothWinDefault = get_cfg_value(cfg, 'extract.binarySmoothWin', 7);
minSegmentPtsDefault = get_cfg_value(cfg, 'extract.minSegmentPts', 3);

% New physical-unit parameters.
dsTarget_um = get_cfg_value(cfg, 'arc.ds_um', []);
phaseSmooth_um = get_cfg_value(cfg, 'extract.phaseSmooth_um', []);
binarySmooth_um = get_cfg_value(cfg, 'extract.binarySmooth_um', []);
minSegment_um = get_cfg_value(cfg, 'extract.minSegment_um', []);

edgeTrimFraction = get_cfg_value(cfg, 'arc.edgeTrimFraction', 0);

for ir = 1:nR
    r_um = rList(ir);

    nTheta = choose_nTheta_for_radius(r_um, nThetaDefault, dsTarget_um);

    tr = samplePhaseAlongArc_legacy(phase_deg, x_um, y_um, ...
        xc_um, yc_um, r_um, nTheta, edgeTrimFraction);

    arc(ir).r = r_um;
    arc(ir).theta = tr.theta_rad;
    arc(ir).s = tr.s_um;
    arc(ir).x = tr.x_um;
    arc(ir).y = tr.y_um;
    arc(ir).phase = tr.phaseWrapped_deg;
    arc(ir).phaseWrapped_deg = tr.phaseWrapped_deg;
    arc(ir).phaseUnwrapped_deg = tr.phaseUnwrapped_deg;

    if numel(tr.s_um) < 20
        details(ir).message = 'arc too short';
        continue;
    end

    dsEff_um = median(diff(tr.s_um), 'omitnan');

    phaseSmoothWin = choose_window_points(phaseSmooth_um, dsEff_um, phaseSmoothWinDefault);
    binarySmoothWin = choose_window_points(binarySmooth_um, dsEff_um, binarySmoothWinDefault);
    minSegmentPts = choose_min_segment_points(minSegment_um, dsEff_um, minSegmentPtsDefault);

    a = analyzeDutyFromPhaseTrace_legacy(tr.s_um, tr.phaseWrapped_deg, ...
        phaseSmoothWin, binarySmoothWin, minSegmentPts);

    a.dsEff_um = dsEff_um;
    a.phaseSmoothWin = phaseSmoothWin;
    a.binarySmoothWin = binarySmoothWin;
    a.minSegmentPts = minSegmentPts;
    a.nTheta = nTheta;

    dutyMean(ir)   = a.dutyMean;
    dutyStd(ir)    = a.dutyStd;
    periodMean(ir) = a.periodMean_um;
    periodStd(ir)  = a.periodStd_um;
    nPeriods(ir)   = a.nPeriods;

    details(ir).trace = tr;
    details(ir).analysis = a;
    details(ir).message = 'ok';
end

analysis = struct();
analysis.center = center;
analysis.radiusList = rList;
analysis.arc = arc;
analysis.periodMean = periodMean;
analysis.periodStd = periodStd;
analysis.dutyMean = dutyMean;
analysis.dutyStd = dutyStd;
analysis.nPeriods = nPeriods;
analysis.details = details;

end

function nTheta = choose_nTheta_for_radius(r_um, nThetaDefault, dsTarget_um)
    if isempty(dsTarget_um) || ~isfinite(dsTarget_um) || dsTarget_um <= 0
        nTheta = nThetaDefault;
        return;
    end

    nTheta = ceil(2*pi*r_um / dsTarget_um) + 1;

    % Keep at least the old value so old configs do not become coarser.
    nTheta = max(nTheta, nThetaDefault);

    % Avoid too-small values.
    nTheta = max(nTheta, 1000);
end

function w = choose_window_points(length_um, dsEff_um, fallbackWin)
    if isempty(length_um) || ~isfinite(length_um) || length_um <= 0 || ...
            isempty(dsEff_um) || ~isfinite(dsEff_um) || dsEff_um <= 0
        w = fallbackWin;
    else
        w = round(length_um / dsEff_um);
    end

    w = sanitize_window_points(w);
end

function w = choose_min_segment_points(length_um, dsEff_um, fallbackPts)
    if isempty(length_um) || ~isfinite(length_um) || length_um <= 0 || ...
            isempty(dsEff_um) || ~isfinite(dsEff_um) || dsEff_um <= 0
        w = fallbackPts;
    else
        w = ceil(length_um / dsEff_um);
    end

    w = max(1, round(w));
end

function w = sanitize_window_points(w)
    if isempty(w) || ~isfinite(w) || w < 1
        w = 1;
    end

    w = round(w);

    % Use odd windows for more symmetric local smoothing.
    if mod(w, 2) == 0
        w = w + 1;
    end
end

function trace = samplePhaseAlongArc_legacy(phase_deg, x_um, y_um, xc_um, yc_um, r_um, nTheta, edgeTrimFraction)
    theta = linspace(-pi, pi, nTheta);

    xq = xc_um + r_um * cos(theta);
    yq = yc_um + r_um * sin(theta);

    % Interpolate the unit phasor instead of the wrapped phase itself.
    C = cosd(phase_deg);
    S = sind(phase_deg);

    Cq = interp2(x_um, y_um, C, xq, yq, 'linear', NaN);
    Sq = interp2(x_um, y_um, S, xq, yq, 'linear', NaN);

    valid = isfinite(Cq) & isfinite(Sq) & ...
            xq >= min(x_um) & xq <= max(x_um) & ...
            yq >= min(y_um) & yq <= max(y_um);

    [i1, i2] = longestTrueRun_legacy(valid);

    trace = emptyTrace_legacy(r_um);
    if isempty(i1), return; end

    % Optional edge trimming after selecting the longest visible arc.
    if nargin >= 8 && ~isempty(edgeTrimFraction) && isfinite(edgeTrimFraction) && edgeTrimFraction > 0
        edgeTrimFraction = min(max(edgeTrimFraction, 0), 0.45);
        nSeg = i2 - i1 + 1;
        nTrim = floor(edgeTrimFraction * nSeg);
        if nSeg - 2*nTrim >= 20
            i1 = i1 + nTrim;
            i2 = i2 - nTrim;
        end
    end

    theta_seg = theta(i1:i2);
    x_seg = xq(i1:i2);
    y_seg = yq(i1:i2);
    zc = Cq(i1:i2) + 1i*Sq(i1:i2);

    trace.r_um = r_um;
    trace.theta_rad = theta_seg;
    trace.x_um = x_seg;
    trace.y_um = y_seg;
    trace.s_um = r_um * (theta_seg - theta_seg(1));
    trace.phaseUnwrapped_deg = rad2deg(unwrap(angle(zc)));
    trace.phaseWrapped_deg = wrapTo180_legacy(trace.phaseUnwrapped_deg);
end

function trace = emptyTrace_legacy(r_um)
    trace.r_um = r_um;
    trace.theta_rad = [];
    trace.x_um = [];
    trace.y_um = [];
    trace.s_um = [];
    trace.phaseWrapped_deg = [];
    trace.phaseUnwrapped_deg = [];
end

function a = analyzeDutyFromPhaseTrace_legacy(s_um, phaseWrapped_deg, phaseSmoothWin, binarySmoothWin, minSegmentPts)
    a = struct('dutyMean',NaN, 'dutyStd',NaN, 'dutySEM',NaN, ...
               'periodMean_um',NaN, 'periodStd_um',NaN, 'periodSEM_um',NaN, ...
               'nPeriods',0);

    if numel(s_um) < 20, return; end

    phaseSmoothWin = sanitize_window_points(phaseSmoothWin);
    binarySmoothWin = sanitize_window_points(binarySmoothWin);
    minSegmentPts = max(1, round(minSegmentPts));

    Csm = movmean(cosd(phaseWrapped_deg), phaseSmoothWin, 'omitnan');
    Ssm = movmean(sind(phaseWrapped_deg), phaseSmoothWin, 'omitnan');

    phiSm_deg = atan2d(Ssm, Csm);
    XY = [cosd(phiSm_deg(:)), sind(phiSm_deg(:))];

    good = all(isfinite(XY),2) & isfinite(s_um(:));
    XY = XY(good,:);
    s2 = s_um(good);

    if numel(s2) < 20, return; end

    idx = simpleKMeans2D_legacy(XY, 50);

    phi1 = atan2d(mean(XY(idx==1,2)), mean(XY(idx==1,1)));
    phi2 = atan2d(mean(XY(idx==2,2)), mean(XY(idx==2,1)));

    if phi1 < phi2
        binary = (idx == 1);
    else
        binary = (idx == 2);
    end

    binary = movmedian(double(binary), binarySmoothWin) > 0.5;
    binary = removeShortRuns_legacy(binary, minSegmentPts);

    [dutyList, periodList] = dutyFromBinaryTrace_legacy(s2, binary);
    valid = isfinite(dutyList) & isfinite(periodList);

    dutyList = dutyList(valid);
    periodList = periodList(valid);

    if isempty(dutyList), return; end

    a.nPeriods = numel(dutyList);

    a.dutyMean = mean(dutyList);
    a.dutyStd  = std(dutyList);
    a.dutySEM  = a.dutyStd / sqrt(a.nPeriods);

    a.periodMean_um = mean(periodList);
    a.periodStd_um  = std(periodList);
    a.periodSEM_um  = a.periodStd_um / sqrt(a.nPeriods);
end

function idx = simpleKMeans2D_legacy(X, maxIter)
    N = size(X,1);

    xMean = mean(X,1);
    [~, i1] = max(sum((X - xMean).^2, 2));
    [~, i2] = max(sum((X - X(i1,:)).^2, 2));
    centers = [X(i1,:); X(i2,:)];

    idx = zeros(N,1);

    for it = 1:maxIter
        idxOld = idx;

        D1 = sum((X - centers(1,:)).^2, 2);
        D2 = sum((X - centers(2,:)).^2, 2);

        idx = ones(N,1);
        idx(D2 < D1) = 2;

        if any(idx==1), centers(1,:) = mean(X(idx==1,:), 1); end
        if any(idx==2), centers(2,:) = mean(X(idx==2,:), 1); end

        if isequal(idx, idxOld), break; end
    end
end

function b = removeShortRuns_legacy(b, minRun)
    b = removeShortTrueRuns_legacy(logical(b(:).'), minRun);
    b = ~removeShortTrueRuns_legacy(~b, minRun);
end

function b = removeShortTrueRuns_legacy(b, minRun)
    d = diff([false, b, false]);
    starts = find(d==1);
    ends   = find(d==-1)-1;

    for k = 1:numel(starts)
        if ends(k)-starts(k)+1 < minRun
            b(starts(k):ends(k)) = false;
        end
    end
end

function [dutyList, periodList] = dutyFromBinaryTrace_legacy(s, b)
    s = s(:).';
    b = logical(b(:).');

    dutyList = NaN;
    periodList = NaN;

    if numel(s) ~= numel(b) || numel(s) < 4, return; end

    edgeIdx = find(diff([b(1), b]) ~= 0);
    if isempty(edgeIdx), return; end

    segStart = [1, edgeIdx];
    segEnd   = [edgeIdx-1, numel(b)];
    nSeg = numel(segStart);

    if nSeg < 4, return; end

    ds = mean(diff(s));
    segState = false(1,nSeg);
    segLen = zeros(1,nSeg);

    for k = 1:nSeg
        segState(k) = mode(b(segStart(k):segEnd(k)));
        segLen(k) = s(segEnd(k)) - s(segStart(k)) + ds;
    end

    % Discard first/last partial segments.
    segState = segState(2:end-1);
    segLen   = segLen(2:end-1);

    nPair = floor(numel(segLen)/2);
    dutyList = nan(1,nPair);
    periodList = nan(1,nPair);

    for k = 1:nPair
        ii = (2*k-1):(2*k);

        w1 = sum(segLen(ii) .* segState(ii));
        w0 = sum(segLen(ii) .* (~segState(ii)));

        periodList(k) = w1 + w0;
        dutyList(k) = w1 / periodList(k);
    end
end

function [i1, i2] = longestTrueRun_legacy(mask)
    mask = logical(mask(:).');

    d = diff([false, mask, false]);
    starts = find(d==1);
    ends   = find(d==-1)-1;

    if isempty(starts)
        i1 = [];
        i2 = [];
        return;
    end

    [~, idx] = max(ends - starts + 1);
    i1 = starts(idx);
    i2 = ends(idx);
end

function y = wrapTo180_legacy(x)
    y = mod(x + 180, 360) - 180;
end

function v = get_cfg_value(cfg, fieldPath, defaultValue)
    parts = strsplit(fieldPath, '.');
    s = cfg;
    for ii = 1:numel(parts)
        if isstruct(s) && isfield(s, parts{ii})
            s = s.(parts{ii});
        else
            v = defaultValue;
            return;
        end
    end
    v = s;
    if isempty(v)
        v = defaultValue;
    end
end
