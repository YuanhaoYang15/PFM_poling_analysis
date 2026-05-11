function y = wrap_to_180_local(x)
%WRAP_TO_180_LOCAL Wrap angle in degrees to [-180, 180].

y = mod(x + 180, 360) - 180;

end
