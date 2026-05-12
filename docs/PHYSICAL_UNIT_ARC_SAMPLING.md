# Physical-unit arc sampling and smoothing

This patch changes the extraction scale from point-count based to physical-unit based.

Recommended config fields:

```matlab
%% Circular arc sampling
cfg.arc.thetaRange = [];
cfg.arc.nTheta = 8000;          % fallback/minimum full-circle samples
cfg.arc.ds_um = 0.04;           % preferred arc-length sampling step
cfg.arc.edgeTrimFraction = 0.03;

%% Domain extraction
cfg.extract.phaseSmooth_um  = 0.30;
cfg.extract.binarySmooth_um = 0.20;
cfg.extract.minSegment_um   = 0.10;

% Keep old point-count fields as fallback:
cfg.extract.phaseSmoothWin  = 9;
cfg.extract.binarySmoothWin = 7;
cfg.extract.minSegmentPts   = 3;
```

Why this matters:

Old behavior used `cfg.arc.nTheta` as a fixed full-circle sample count.
For larger radius, the actual arc-length step became larger:

```text
ds ≈ 2*pi*r / nTheta
```

Therefore point-count smoothing corresponded to different physical lengths for different devices.

New behavior:

```text
given cfg.arc.ds_um
→ choose nTheta for each radius so ds is approximately constant
given cfg.extract.*_um
→ convert smoothing/min-segment lengths into point counts using actual ds
```
