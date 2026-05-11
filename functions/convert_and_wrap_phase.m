function phase = convert_and_wrap_phase(phase, cfg)
%CONVERT_AND_WRAP_PHASE Convert phase unit and wrap to [-180, 180].

unit = 'deg';
offsetDeg = 0;

if isfield(cfg, 'preprocess')
    unit = cfg.preprocess.phaseUnit;
    offsetDeg = cfg.preprocess.phaseOffsetDeg;
elseif isfield(cfg, 'load')
    if isfield(cfg.load, 'phaseUnit'); unit = cfg.load.phaseUnit; end
    if isfield(cfg.load, 'phaseOffsetDeg'); offsetDeg = cfg.load.phaseOffsetDeg; end
end

if strcmpi(unit, 'rad')
    phase = phase * 180/pi;
end

phase = phase + offsetDeg;
phase = wrap_to_180_local(phase);

end
