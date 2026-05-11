function yl = get_period_ylim(cfg, rList, lambdaDesign, measuredValues)
%GET_PERIOD_YLIM Consistent y-limits for period plots.
mode = get_nested_field(cfg, 'plot.periodYLimMode', 'design_pm');
halfRange = get_nested_field(cfg, 'plot.periodYLimHalfRange', 1.0);

switch lower(mode)
    case {'design_pm','design'}
        yl = [min(lambdaDesign, [], 'omitnan') - halfRange, ...
              max(lambdaDesign, [], 'omitnan') + halfRange];
    case {'ref_pm','reference'}
        ref = cfg.design.periodRef.LambdaRef;
        yl = [ref - halfRange, ref + halfRange];
    case {'auto'}
        vals = [lambdaDesign(:); measuredValues(:)];
        vals = vals(isfinite(vals));
        if isempty(vals)
            yl = [cfg.extract.minPeriodUm, cfg.extract.maxPeriodUm];
        else
            pad = 0.15;
            yl = [min(vals)-pad, max(vals)+pad];
        end
    otherwise
        yl = [min(lambdaDesign, [], 'omitnan') - halfRange, ...
              max(lambdaDesign, [], 'omitnan') + halfRange];
end

if any(~isfinite(yl)) || diff(yl) <= 0
    yl = [1, 5];
end
end
