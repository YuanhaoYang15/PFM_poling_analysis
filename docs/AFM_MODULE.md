# AFM topography module

This module adds basic AFM surface-topography analysis to the PFM poling
toolkit. It is intentionally separate from the PFM duty-cycle workflow: AFM
scans have no device/design/center/period metadata, so they use their own
config, entry points, and results tree.

## Scope

Current version:

- read NanoScope ASCII `.txt` exports (same reader family as the PFM side);
- raw-channel QC heatmaps for every exported channel;
- waveguide orientation detection from the dominant edge orientation;
- height leveling with a linear plane fitted only on the far-field regions
  (outside the ridge and trenches);
- slice perpendicular to the waveguide and step-height extraction:
  ridge top to far field (primary etch depth) and ridge top to moat.

Not yet implemented:

- `.spm` binary reading (txt exports are required for now);
- roughness maps, grain analysis, FFT/periodicity, multi-scan statistics.

## Entry points

```matlab
main_afm_generate_metadata   % scan raw/ and merge metadata/afm_scans.csv
main_afm_plot_channels       % raw-channel QC heatmaps -> results/afm/raw_qc
main_afm_analyze_batch       % orientation + far-field leveling + step heights
```

The active AFM batch is selected in `local/active_afm_batch_config.m`
(copied from `local/active_afm_batch_config_template.m`).

## Private layout

```text
local/batches/<batchName>/
  raw/                         NanoScope txt exports (and spm, unused for now)
  metadata/afm_scans.csv       generated, then edited by hand
  results/afm/
    raw_qc/                    per-channel heatmaps + manifest
    processed_data/
      <rawName>_processed.mat
      afm_summary_<batchName>.csv
    figures/
      <rawName>_summary.png
    progress.log
```

## Metadata

`generate_afm_metadata` scans the raw folder with
`cfg.afm.naming.pattern`, reads the scan size and image size from each file
header, and merges rows into `metadata/afm_scans.csv`.

Columns:

```text
rawName, fileName, sample, gain, scanID, scanSizeX_um, scanSizeY_um,
nx, ny, expectedDepth_nm, include, notes
```

Auto columns (`fileName`, `sample`, `gain`, `scanID`, scan size, image size)
are refreshed on every run. Manual columns (`expectedDepth_nm`, `include`,
`notes`) and any extra columns are preserved.

## Channels

The reader auto-detects the data header line and cleans channel names, so a
file with the header

```text
Height_Sensor(nm)  Amplitude_Error(V)  Phase(deg)  Height(nm)
```

becomes `D.Height_Sensor`, `D.Amplitude_Error`, `D.Phase`, `D.Height`.

Config:

```matlab
cfg.afm.heightField = 'Height_Sensor';   % primary topography channel
cfg.afm.crossCheckField = 'Height';      % cross-check channel
```

The two channels are independent calibrations of the same surface. On the
20260914_AFM ridge data, `Height_Sensor` matches the designed 400 nm etch
depth, while `Height` reads about 20-25% larger, so `Height_Sensor` is the
default and `Height` is reported as a cross-check.

## Analysis chain

### 1. Waveguide orientation

`detect_afm_waveguide_angle` builds a weighted histogram of gradient
orientations over the strongest gradient pixels. Edges along the waveguide
dominate, so the histogram peak gives the waveguide axis
(`waveguideAngle_deg`, deg from the x axis). The slice direction is
perpendicular to it and is used as the coordinate

```text
u = x*cosd(a) + y*sind(a)
```

```matlab
cfg.afm.orientation.override_deg = [];   % set a number to skip detection
cfg.afm.orientation.gradientPercentile = 90;
cfg.afm.orientation.smoothBins = 5;
cfg.afm.orientation.peakWindow_deg = 5;
```

### 2. Far-field leveling

`afm_farfield_mask` finds the ridge edges as the mid-level crossings of the
raw cross-waveguide profile, searches outward from each edge for the local
floor minimum (moat), and defines the far field as everything beyond each
moat plus `farFieldMargin_um`. `level_afm_farfield` then fits a linear plane
`z = a*x + b*y + c` on the far-field pixels only and subtracts it, so the
ridge and trenches do not bias the correction.

```matlab
cfg.afm.level.method = 'farfield_plane';  % farfield_plane | plane | plane_line | none
cfg.afm.level.moatSearch_um = 0.6;        % search floor minimum outward from each edge
cfg.afm.level.moatWindow_um = 0.05;       % robust window around the moat minimum
cfg.afm.level.farFieldMargin_um = 0.1;    % far field starts this far beyond the moat
cfg.afm.level.plateauLeveling = true;     % per-plateau plane fit for the ridge top
```

The summary keeps the residual far-field slopes and RMS so the leveling
quality is visible.

### 3. Profile and step heights

The cross-waveguide profile is the median of the leveled image in u bins.
`extract_afm_step` measures the ridge-top plateau, the ridge edges and
width, the far-field levels, and the moat levels.

Two step definitions are reported:

```text
stepLeft_nm / stepRight_nm   : ridge top - far field  (primary etch depth)
stepMoatLeft_nm / stepMoatRight_nm : ridge top - moat (deeper groove at the edge)
```

The moat is usually a shallow feature next to the ridge (tip/etch related);
the far-field step is the process etch depth.

### 4. Sidewall angle

`extract_afm_sidewall` fits the linear portion of each sidewall between
`lowFraction` and `highFraction` (default 10-90%) of the local step height
(moat level to ridge top) and reports the angle relative to the horizontal.
The median profile gives the primary angle; per-slice angles on a rotated
resampling give the uniformity (mean, std, p10, p90).

```matlab
cfg.afm.sidewall.lowFraction = 0.10;
cfg.afm.sidewall.highFraction = 0.90;
cfg.afm.sidewall.nSlices = 120;
```

Tip convolution rounds the top corner, so the 10-90% range is used instead
of the full wall. The top and base widths of the ridge are reported as
well (`ridgeTopWidth_um`, `ridgeBaseWidth_um`).

Two illustration figures can be generated per scan with
`main_afm_plot_sidewall_qc` (reusing the processed MAT files):

```text
<rawName>_sidewall_definition.png : profile with the 10-90% fit segments,
                                    horizontal references, angle arcs and H
<rawName>_sidewall_vs_slice.png   : left/right angle per slice along the
                                    waveguide (mean, std, +-1 sigma band)
```

### 5. 3-D reconstruction

`plot_afm_3d_surface` writes a standalone per-scan 3-D surface PNG
(`<rawName>_3d.png`) of the leveled height, with lighting and a
configurable vertical exaggeration. The surface is drawn with the
exaggerated height while the color mapping and the z tick labels keep the
true height.

```matlab
cfg.plot.save3d = true;
cfg.plot.surfaceDownsample = 2;
cfg.plot.verticalExaggeration = 8;
```

## Summary columns

```text
rawName, sample, gain, scanID, scanSizeX_um, nx, ny,
angle_deg, waveguideAngle_deg,
ridgeLeft_um, ridgeRight_um, ridgeWidth_um,
topLevel_nm, farLeft_nm, farRight_nm, moatLeft_nm, moatRight_nm,
stepLeft_nm, stepRight_nm, stepMean_nm, asymmetry_nm,
stepMoatLeft_nm, stepMoatRight_nm,
sidewallLeft_deg, sidewallRight_deg,
sidewallLeftMean_deg, sidewallLeftStd_deg,
sidewallRightMean_deg, sidewallRightStd_deg,
ridgeTopWidth_um, ridgeBaseWidth_um,
topRq_nm, farRms_nm, farSlopeLeft_nm_per_um, farSlopeRight_nm_per_um,
farPixels, rowJumpMax_nm, rowJumpCount, qualityFlag, stepFlag,
xcheckField, xcheck_stepLeft_nm, xcheck_stepRight_nm,
expectedDepth_nm, depthError_nm, notes
```

`angle_deg` is the slice angle (perpendicular to the waveguide),
`waveguideAngle_deg` is the detected waveguide axis. `qualityFlag` is `ok`
or `row_jump` (row-median jumps above
`cfg.afm.quality.rowJumpThreshold_nm`), which marks horizontal streak
artifacts. `stepFlag` is `ok` or a combination of
`open_profile` / `narrow_ridge` / `left_floor_clipped` / `right_floor_clipped`.

## 20260914_AFM example

Sample tag `600etch400`: 600 nm film thickness, 400 nm designed etch depth.
Four tapping-AFM scans of the same ridge (2.5 um gain 0.5; 3 um gain 1 twice;
5 um gain 1). `Height_Sensor`, far-field plane leveling:

```text
scan             waveguide   etch left   etch right   moat left   moat right   sidewall L   sidewall R   width
2.5 um gain 0.5   91.8 deg    411 nm      410 nm       439 nm      443 nm       48.1 deg     51.3 deg     1.04 um
3 um gain 1 (a)   92.4 deg    403 nm      405 nm       436 nm      423 nm       48.8 deg     51.5 deg     1.02 um   row_jump flag
3 um gain 1 (b)   92.6 deg    405 nm      406 nm       443 nm      442 nm       48.7 deg     50.2 deg     1.04 um
5 um gain 1       92.7 deg    398 nm      400 nm       444 nm      437 nm       48.6 deg     51.9 deg     1.03 um
```

The waveguide is tilted about 2-3 deg from the image y axis. After far-field
leveling, the etch depth is 398-411 nm on both sides (mean about 404 nm),
close to the 400 nm design value, and the left/right asymmetry is within a
few nm. The moat next to the ridge is 425-445 nm deep. The sidewall angle is
about 48-49 deg on the left and 50-52 deg on the right; per-slice std is
below 1 deg, so the sidewalls are uniform along the ridge. On the 5 um
scan, the ridge top width is 0.56 um and the base width (moat to moat) is
1.41 um. Each scan also gets a `<rawName>_3d.png` surface reconstruction
next to the summary figure.

## Adding a new AFM batch

1. Put the txt exports in `local/batches/<newBatch>/raw/`.
2. Copy `config/config_afm_20260914_AFM.m` to
   `config/config_afm_<newBatch>.m` and update `cfg.batchName`, the naming
   pattern, and the expected depth.
3. Point `local/active_afm_batch_config.m` at the new config.
4. Run the three entry points.
