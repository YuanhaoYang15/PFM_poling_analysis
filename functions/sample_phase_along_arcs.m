function arc = sample_phase_along_arcs(data, center, rList, cfg)
%SAMPLE_PHASE_ALONG_ARCS Sample PFM phase along circular arcs.

nR = numel(rList);
arc = repmat(struct(), 1, nR);

for ii = 1:nR
    r = rList(ii);

    thetaRange = cfg.arc.thetaRange;
    if isempty(thetaRange)
        thetaRange = estimate_valid_theta_range(data, center, r);
    end

    theta = linspace(thetaRange(1), thetaRange(2), cfg.arc.nTheta);
    xq = center(1) + r * cos(theta);
    yq = center(2) + r * sin(theta);

    phase = interp2(data.X, data.Y, data.phase, xq, yq, 'linear', NaN);

    valid = ~isnan(phase);
    if any(valid)
        idx = find(valid);
        i1 = idx(1);
        i2 = idx(end);

        trimN = round((i2 - i1 + 1) * cfg.arc.edgeTrimFraction);
        i1 = min(i2, i1 + trimN);
        i2 = max(i1, i2 - trimN);

        keep = false(size(valid));
        keep(i1:i2) = valid(i1:i2);

        theta = theta(keep);
        xq = xq(keep);
        yq = yq(keep);
        phase = phase(keep);
    else
        theta = [];
        xq = [];
        yq = [];
        phase = [];
    end

    s = r * (theta - theta(1));

    arc(ii).r = r;
    arc(ii).theta = theta;
    arc(ii).s = s;
    arc(ii).x = xq;
    arc(ii).y = yq;
    arc(ii).phase = phase;
end

end

function thetaRange = estimate_valid_theta_range(data, center, r)
    theta0 = linspace(-pi, pi, 3000);
    xq = center(1) + r * cos(theta0);
    yq = center(2) + r * sin(theta0);
    ph = interp2(data.X, data.Y, data.phase, xq, yq, 'linear', NaN);
    valid = ~isnan(ph);

    if ~any(valid)
        thetaRange = [-pi, pi];
        return;
    end

    d = diff([false, valid, false]);
    startIdx = find(d == 1);
    endIdx = find(d == -1) - 1;
    [~, k] = max(endIdx - startIdx + 1);

    thetaRange = [theta0(startIdx(k)), theta0(endIdx(k))];
end
