function [J, info] = center_stripe_coherence(center, X, Y, I, N, rRange, taper_um, minPixels)
%CENTER_STRIPE_COHERENCE Normalized design angular harmonic in an annulus.

if numel(center) ~= 2 || any(~isfinite(center(:)))
    error('center_stripe_coherence:InvalidCenter', 'Center must contain two finite coordinates.');
end
if ~isequal(size(X), size(Y), size(I))
    error('center_stripe_coherence:InvalidImage', 'X, Y and I must have the same size.');
end
if ~isscalar(N) || ~isfinite(N) || N <= 0 || ...
        numel(rRange) ~= 2 || any(~isfinite(rRange(:))) || ...
        rRange(2) < rRange(1) || ~isscalar(taper_um) || ...
        ~isfinite(taper_um) || taper_um <= 0 || ...
        ~isscalar(minPixels) || ~isfinite(minPixels) || minPixels < 0
    error('center_stripe_coherence:InvalidSettings', 'Invalid harmonic, annulus, taper or pixel threshold.');
end

J = 0;
info = struct('nPixels', 0, 'phase', NaN, 'thetaRef', NaN);
finitePixel = isfinite(X) & isfinite(Y) & isfinite(I);
x = double(X(finitePixel));
y = double(Y(finitePixel));
value = double(I(finitePixel));
center = double(center(:).');
dx = x(:) - center(1);
dy = y(:) - center(2);
value = value(:);
r = hypot(dx, dy);
w = min(1, max(0, min(r - rRange(1), rRange(2) - r) / taper_um + 0.5));
mask = w > 0;
info.nPixels = nnz(mask);
if info.nPixels == 0 || info.nPixels < minPixels
    return;
end

dx = dx(mask);
dy = dy(mask);
w = w(mask);
value = value(mask);
info.thetaRef = atan2(mean(y(mask)) - center(2), mean(x(mask)) - center(1));
if all(value == value(1))
    info.phase = 0;
    return;
end
theta = angle(complex(dx, dy) * exp(-1i * info.thetaRef));
sumW = sum(w);
v = value - sum(w .* value) / sumW;
z = sum(w .* v .* exp(-1i * N * theta));
info.phase = angle(z);
denominator = sqrt(sumW * sum(w .* v.^2));
if denominator > 0 && isfinite(denominator) && isfinite(z)
    J = abs(z) / denominator;
end
end
