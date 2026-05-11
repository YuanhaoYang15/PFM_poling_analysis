function lambda = design_period(rList, cfg)
%DESIGN_PERIOD Designed circular poling period at each radius.

Rref = cfg.design.periodRef.Rref;
LambdaRef = cfg.design.periodRef.LambdaRef;

lambda = LambdaRef .* rList ./ Rref;

end
