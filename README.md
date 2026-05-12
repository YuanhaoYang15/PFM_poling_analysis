# PFM Poling Analysis

A lightweight MATLAB analysis project for processing PFM phase scans of circularly poled devices. The workflow focuses on reproducible extraction of poling period and duty cycle, with center-position correction based on the designed poling period.

## Motivation

For circular poling patterns, the extracted period and duty cycle can be sensitive to the assumed device center. Even a small center offset can lead to a systematic error in the measured period versus radius. This project provides a structured workflow to:

- load and visualize PFM phase maps;
- sample phase data along circular arcs;
- extract poling period and duty cycle as functions of radius;
- correct the assumed center using the designed period as a reference;
- compare multiple PFM scans from the same device;
- save processed data and summary figures for traceable analysis.

The project is designed for devices where each physical device may have multiple PFM scans, named for example as `_1`, `_2`, `_3`, etc. These scans may correspond to different positions, repeated measurements, or regions at different distances from electrodes. The analysis does not assume a fixed “near/far” structure.

## Concept

For a circularly poled device with angular period \(\Delta\theta\), the designed poling period along a radius \(r\) is approximately

\[
\Lambda_\mathrm{design}(r) = r \Delta\theta .
\]

If the designed period is known at a reference radius \(R_\mathrm{ref}\),

\[
\Delta\theta = \frac{\Lambda_\mathrm{ref}}{R_\mathrm{ref}},
\]

and therefore

\[
\Lambda_\mathrm{design}(r)
=
\Lambda_\mathrm{ref}
\frac{r}{R_\mathrm{ref}} .
\]

The center correction is performed by scanning candidate center positions around the initial estimate and selecting the center that makes the measured period curve best match the designed period curve.

Importantly, the center correction should use period information only. Duty cycle should not be used in the optimization, because duty cycle is one of the physical quantities to be compared after correction.

## Suggested Repository Structure

```text
PFM_poling_analysis/
│
├─ README.md
├─ main_analyze_one_device.m
├─ main_analyze_all_devices.m
│
├─ config/
│   ├─ config_E7_R1C2.m
│   ├─ config_E7_R1C3.m
│   └─ config_template.m
│
├─ functions/
│   ├─ load_pfm_data.m
│   ├─ sample_phase_along_arcs.m
│   ├─ extract_period_duty_vs_radius.m
│   ├─ optimize_center_by_period.m
│   ├─ plot_summary_figure.m
│   ├─ plot_compare_scans.m
│   └─ save_processed_results.m
│
├─ raw_data/
├─ processed_data/
└─ figures/
```

## Device and Scan Abstraction

The recommended abstraction is:

```text
one device → N PFM scans
```

Each device has shared design parameters, such as:

- nominal center radius;
- waveguide width;
- designed period at a reference radius;
- radius range used for analysis;
- center-optimization settings.

Each scan has its own measurement-specific parameters, such as:

- raw data filename;
- scan index;
- initial center estimate;
- optional position label;
- optional notes about scan quality.

Example:

```matlab
cfg.deviceName = 'E7_R1C2';

cfg.design.R0 = 30.0;                  % um
cfg.design.w  = 1.0;                   % um

cfg.design.periodRef.Rref = 30.0;      % um
cfg.design.periodRef.LambdaRef = 2.5;  % um

cfg.radius.rMin = 28.0;
cfg.radius.rMax = 35.0;
cfg.radius.dr   = 0.1;

cfg.centerOpt.enable = true;
cfg.centerOpt.searchRange = 2.0;       % um
cfg.centerOpt.searchStep  = 0.05;      % um

cfg.scans(1).scanID = 1;
cfg.scans(1).fileName = 'Data_UF_2p5_r1c2_1_260511';
cfg.scans(1).centerInitial = [xc1, yc1];
cfg.scans(1).positionLabel = '';

cfg.scans(2).scanID = 2;
cfg.scans(2).fileName = 'Data_UF_2p5_r1c2_2_260511';
cfg.scans(2).centerInitial = [xc2, yc2];
cfg.scans(2).positionLabel = '';
```

## Basic Workflow

1. Define a device-level configuration file.
2. Add all PFM scans belonging to the same device.
3. Run `main_analyze_one_device.m`.
4. For each scan:
   - load PFM data;
   - plot the raw phase map;
   - sample phase along circular arcs;
   - extract period and duty cycle versus radius;
   - optimize the center using the designed period curve;
   - re-extract period and duty cycle using the optimized center;
   - save processed data and summary figures.
5. Compare all scans from the same device.

## Recommended Saved Results

Each processed scan should save both the initial and corrected analysis results:

```matlab
result.rawFileName
result.deviceName
result.scanID

result.centerInitial
result.centerOptimized
result.centerShift

result.radiusList

result.period_before
result.period_after
result.period_std_after

result.duty_after
result.duty_std_after

result.WG_period_mean
result.WG_period_std
result.WG_duty_mean
result.WG_duty_std

result.config
```

The all-scan summary can additionally save:

```matlab
summary.deviceName
summary.scanIDs
summary.centerInitial_all
summary.centerOptimized_all
summary.WG_period_mean_all
summary.WG_duty_mean_all
summary.WG_period_std_all
summary.WG_duty_std_all
```

## Output Figures

For each scan, the standard summary figure should contain:

1. PFM phase map with circular radius markers and waveguide region.
2. Phase traces along selected circular arcs.
3. Duty cycle versus radius.
4. Poling period versus radius.

For each device, the comparison figure may contain:

1. Period versus radius for all scans before center correction.
2. Period versus radius for all scans after center correction.
3. Duty cycle versus radius after center correction.
4. Waveguide-region averaged duty cycle for all scans.

## Notes

- The designed period should be used only as a geometric reference for center correction.
- Duty-cycle differences should be interpreted after center correction.
- Large local period outliers may indicate failed domain detection, merged domains, missing domains, or poor PFM contrast.
- The analysis should always save the configuration used for each run, so that every result can be reproduced later.
- Raw data files are usually not tracked by Git if they are large or private.

## Git Ignore Recommendation

A typical `.gitignore` may include:

```gitignore
# MATLAB temporary files
*.asv
*.m~
*.slxc

# Large or private data
raw_data/
processed_data/
figures/

# Local settings
local/
*.mat
```

If some processed examples or representative figures should be tracked, remove the corresponding lines or add exceptions explicitly.
