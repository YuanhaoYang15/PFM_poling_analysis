function analysis = extract_inphase_duty_vs_radius(data, center, rList, cfg)
%EXTRACT_INPHASE_DUTY_VS_RADIUS Extract low-inphase duty versus radius.
%
% Duty definition:
%   low-inphase segment length / one period length.
%
x_um = data.X(1,:);
y_um = data.Y(:,1).';
Z = data.inphase;

nR = numel(rList);
arc = repmat(struct(), 1, nR);

periodMean = nan(1, nR);
periodStd = nan(1, nR);
dutyMean = nan(1, nR);
dutyStd = nan(1, nR);
nPeriods = nan(1, nR);
details = repmat(struct(), 1, nR);

nThetaDefault = get_cfg_value_local(cfg, 'arc.nTheta', 6000);
dsTarget_um = get_cfg_value_local(cfg, 'arc.ds_um', []);
smooth_um = get_cfg_value_local(cfg, 'extract.phaseSmooth_um', []);
binarySmooth_um = get_cfg_value_local(cfg, 'extract.binarySmooth_um', []);
minSegment_um = get_cfg_value_local(cfg, 'extract.minSegment_um', []);
edgeTrimFraction = get_cfg_value_local(cfg, 'arc.edgeTrimFraction', 0);

for ir = 1:nR
    r_um = rList(ir);
    nTheta = choose_nTheta_for_radius_local(r_um, nThetaDefault, dsTarget_um);
    tr = sample_scalar_along_arc_local(Z, x_um, y_um, center, r_um, nTheta, edgeTrimFraction);

    arc(ir).r = r_um;
    arc(ir).theta = tr.theta_rad;
    arc(ir).s = tr.s_um;
    arc(ir).x = tr.x_um;
    arc(ir).y = tr.y_um;
    arc(ir).inphase = tr.value;
    arc(ir).phase = tr.value;

    if numel(tr.s_um) < 20
        details(ir).message = 'arc too short';
        continue;
    end

    dsEff_um = median(diff(tr.s_um), 'omitnan');
    smoothWin = choose_window_points_local(smooth_um, dsEff_um, 9);
    binarySmoothWin = choose_window_points_local(binarySmooth_um, dsEff_um, 7);
    minSegmentPts = choose_min_segment_points_local(minSegment_um, dsEff_um, 3);

    a = analyze_duty_from_scalar_trace_local(tr.s_um, tr.value, ...
        smoothWin, binarySmoothWin, minSegmentPts);

    a.dsEff_um = dsEff_um;
    a.smoothWin = smoothWin;
    a.binarySmoothWin = binarySmoothWin;
    a.minSegmentPts = minSegmentPts;
    a.nTheta = nTheta;

    dutyMean(ir) = a.dutyMean;
    dutyStd(ir) = a.dutyStd;
    periodMean(ir) = a.periodMean_um;
    periodStd(ir) = a.periodStd_um;
    nPeriods(ir) = a.nPeriods;

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
analysis.signal = 'LS_PR_Inphase';
analysis.dutyDefinition = 'low_inphase';

end

function trace = sample_scalar_along_arc_local(Z, x_um, y_um, center, r_um, nTheta, edgeTrimFraction)
theta = linspace(-pi, pi, nTheta);
xq = center(1) + r_um * cos(theta);
yq = center(2) + r_um * sin(theta);
zq = interp2(x_um, y_um, Z, xq, yq, 'linear', NaN);

valid = isfinite(zq) & ...
    xq >= min(x_um) & xq <= max(x_um) & ...
    yq >= min(y_um) & yq <= max(y_um);

[i1, i2] = longest_true_run_local(valid);

if ~all(valid) && valid(1) && valid(end)
    firstEnd = find(~valid, 1, 'first') - 1;
    lastStart = find(~valid, 1, 'last') + 1;
    idx = [lastStart:numel(valid), 2:firstEnd];
    if numel(idx) >= i2 - i1 + 1
        % Keep the +pi sample once, then continue on the next revolution.
        theta = [theta(lastStart:end), theta(2:firstEnd) + 2*pi];
        xq = xq(idx);
        yq = yq(idx);
        zq = zq(idx);
        i1 = 1;
        i2 = numel(idx);
    end
end

trace = empty_trace_local(r_um);
if isempty(i1); return; end

if nargin >= 7 && ~isempty(edgeTrimFraction) && isfinite(edgeTrimFraction) && edgeTrimFraction > 0
    edgeTrimFraction = min(max(edgeTrimFraction, 0), 0.45);
    nSeg = i2 - i1 + 1;
    nTrim = floor(edgeTrimFraction * nSeg);
    if nSeg - 2*nTrim >= 20
        i1 = i1 + nTrim;
        i2 = i2 - nTrim;
    end
end

thetaSeg = theta(i1:i2);
trace.r_um = r_um;
trace.theta_rad = thetaSeg;
trace.x_um = xq(i1:i2);
trace.y_um = yq(i1:i2);
trace.s_um = r_um * (thetaSeg - thetaSeg(1));
trace.value = zq(i1:i2);
end

function a = analyze_duty_from_scalar_trace_local(s_um, value, smoothWin, binarySmoothWin, minSegmentPts)
a = struct('dutyMean', NaN, 'dutyStd', NaN, 'periodMean_um', NaN, ...
    'periodStd_um', NaN, 'nPeriods', 0);

if numel(s_um) < 20; return; end

smoothWin = sanitize_window_points_local(smoothWin);
binarySmoothWin = sanitize_window_points_local(binarySmoothWin);
minSegmentPts = max(1, round(minSegmentPts));

v = movmean(value(:), smoothWin, 'omitnan');
good = isfinite(v) & isfinite(s_um(:));
v = v(good);
s2 = s_um(good);

if numel(s2) < 20; return; end

idx = simple_kmeans_1d_local(v, 50);
m1 = mean(v(idx == 1), 'omitnan');
m2 = mean(v(idx == 2), 'omitnan');

% User-defined physical duty: low inphase, visually the blue domain.
if m1 <= m2
    binary = idx == 1;
else
    binary = idx == 2;
end

binary = movmedian(double(binary), binarySmoothWin) > 0.5;
binary = remove_short_runs_local(binary, minSegmentPts);

[dutyList, periodList] = duty_from_binary_trace_local(s2, binary);
valid = isfinite(dutyList) & isfinite(periodList);
dutyList = dutyList(valid);
periodList = periodList(valid);

if isempty(dutyList); return; end

a.nPeriods = numel(dutyList);
a.dutyMean = mean(dutyList);
a.dutyStd = std(dutyList);
a.periodMean_um = mean(periodList);
a.periodStd_um = std(periodList);
a.binary = binary;
a.s_um = s2;
a.valueSmoothed = v;
end

function idx = simple_kmeans_1d_local(v, maxIter)
v = v(:);
c = [min(v); max(v)];
idx = zeros(size(v));

for it = 1:maxIter
    old = idx;
    [~, idx] = min(abs(v - c.'), [], 2);
    if any(idx == 1); c(1) = mean(v(idx == 1), 'omitnan'); end
    if any(idx == 2); c(2) = mean(v(idx == 2), 'omitnan'); end
    if isequal(idx, old); break; end
end
end

function b = remove_short_runs_local(b, minRun)
b = remove_short_true_runs_local(logical(b(:).'), minRun);
b = ~remove_short_true_runs_local(~b, minRun);
end

function b = remove_short_true_runs_local(b, minRun)
d = diff([false, b, false]);
starts = find(d == 1);
ends = find(d == -1) - 1;

for k = 1:numel(starts)
    if ends(k) - starts(k) + 1 < minRun
        b(starts(k):ends(k)) = false;
    end
end
end

function [dutyList, periodList] = duty_from_binary_trace_local(s, b)
s = s(:).';
b = logical(b(:).');

dutyList = NaN;
periodList = NaN;

if numel(s) ~= numel(b) || numel(s) < 4; return; end

edgeIdx = find(diff([b(1), b]) ~= 0);
if isempty(edgeIdx); return; end

segStart = [1, edgeIdx];
segEnd = [edgeIdx - 1, numel(b)];
if numel(segStart) < 4; return; end

ds = mean(diff(s));
segState = false(1, numel(segStart));
segLen = zeros(1, numel(segStart));

for k = 1:numel(segStart)
    segState(k) = mode(b(segStart(k):segEnd(k)));
    segLen(k) = s(segEnd(k)) - s(segStart(k)) + ds;
end

segState = segState(2:end-1);
segLen = segLen(2:end-1);

nPair = floor(numel(segLen) / 2);
dutyList = nan(1, nPair);
periodList = nan(1, nPair);

for k = 1:nPair
    ii = (2*k-1):(2*k);
    w1 = sum(segLen(ii) .* segState(ii));
    w0 = sum(segLen(ii) .* (~segState(ii)));
    periodList(k) = w1 + w0;
    dutyList(k) = w1 / periodList(k);
end
end

function [i1, i2] = longest_true_run_local(mask)
mask = logical(mask(:).');
d = diff([false, mask, false]);
starts = find(d == 1);
ends = find(d == -1) - 1;

if isempty(starts)
    i1 = [];
    i2 = [];
    return;
end

[~, idx] = max(ends - starts + 1);
i1 = starts(idx);
i2 = ends(idx);
end

function trace = empty_trace_local(r_um)
trace.r_um = r_um;
trace.theta_rad = [];
trace.x_um = [];
trace.y_um = [];
trace.s_um = [];
trace.value = [];
end

function nTheta = choose_nTheta_for_radius_local(r_um, nThetaDefault, dsTarget_um)
if isempty(dsTarget_um) || ~isfinite(dsTarget_um) || dsTarget_um <= 0
    nTheta = nThetaDefault;
    return;
end

nTheta = ceil(2*pi*r_um / dsTarget_um) + 1;
nTheta = max(nTheta, nThetaDefault);
nTheta = max(nTheta, 1000);
end

function w = choose_window_points_local(length_um, dsEff_um, fallbackWin)
if isempty(length_um) || ~isfinite(length_um) || length_um <= 0 || ...
        isempty(dsEff_um) || ~isfinite(dsEff_um) || dsEff_um <= 0
    w = fallbackWin;
else
    w = round(length_um / dsEff_um);
end

w = sanitize_window_points_local(w);
end

function w = choose_min_segment_points_local(length_um, dsEff_um, fallbackPts)
if isempty(length_um) || ~isfinite(length_um) || length_um <= 0 || ...
        isempty(dsEff_um) || ~isfinite(dsEff_um) || dsEff_um <= 0
    w = fallbackPts;
else
    w = ceil(length_um / dsEff_um);
end

w = max(1, round(w));
end

function w = sanitize_window_points_local(w)
if isempty(w) || ~isfinite(w) || w < 1
    w = 1;
end

w = round(w);
if mod(w, 2) == 0
    w = w + 1;
end
end

function v = get_cfg_value_local(cfg, fieldPath, defaultValue)
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
