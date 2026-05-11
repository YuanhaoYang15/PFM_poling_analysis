# PFM Poling Analysis

A lightweight MATLAB project for batch analysis of raw PFM text exports from circularly poled devices.

The workflow is designed for real poling-test batches:

```text
one batch
→ multiple design types
→ multiple devices
→ multiple PFM scans per device
```

Raw data do **not** need to be placed inside this code repository.

## Recommended Workflow

```matlab
main_pick_initial_centers_for_batch
main_analyze_batch
```

The first script opens every scan and lets you manually click an approximate center. The second script performs automatic center correction using the designed poling period, extracts period/duty cycle, and generates scan/device/batch summaries.

## Folder Logic

Code project:

```text
PFM_poling_analysis/
├─ config/
├─ metadata/
├─ functions/
├─ local/
├─ processed_data/
└─ figures/
```

External raw data folders, for example:

```text
D:\Project\NUS\Project\Single Photon Nonlinearity\Image\20260511
D:\Project\NUS\Project\Single Photon Nonlinearity\Image\20260506
```

The raw data paths are configured in:

```text
local/local_paths.m
```

This file is ignored by Git.

## First-Time Setup

Copy:

```matlab
local/local_paths_template.m
```

to:

```matlab
local/local_paths.m
```

Then edit the raw roots:

```matlab
paths.rawRoots.batch_20260511 = ...
    'D:\Project\NUS\Project\Single Photon Nonlinearity\Image\20260511';

paths.rawRoots.batch_20260506 = ...
    'D:\Project\NUS\Project\Single Photon Nonlinearity\Image\20260506';
```

Copy:

```matlab
local/active_batch_config_template.m
```

to:

```matlab
local/active_batch_config.m
```

Then choose the active batch:

```matlab
cfg = config_batch_20260511();
```

or

```matlab
cfg = config_batch_20260506();
```

## Metadata Files

Each batch is controlled by three CSV files:

```text
metadata/designs_20260511.csv
metadata/devices_20260511.csv
metadata/scans_20260511.csv
```

### designs CSV

Defines structure/design types:

```text
designID,R0_um,w_um,Rref_um,LambdaRef_um,rMin_um,rMax_um,dr_um,...
```

### devices CSV

Defines individual devices and their poling parameters:

```text
deviceID,designID,polingGroup,polingVoltage,polingTime,row,col,notes
```

### scans CSV

Defines raw PFM scans:

```text
deviceID,scanID,rawName,phaseFilePattern,positionLabel,centerX_um,centerY_um,notes
```

If `centerX_um` and `centerY_um` are empty, use:

```matlab
main_pick_initial_centers_for_batch
```

to manually click approximate centers.

## Analysis Principle

For a circularly poled device with angular period \(\Delta\theta\), the designed period along radius \(r\) is

\[
\Lambda_\mathrm{design}(r) = r\Delta\theta .
\]

If the designed period is known at \(R_\mathrm{ref}\),

\[
\Lambda_\mathrm{design}(r)
=
\Lambda_\mathrm{ref}
\frac{r}{R_\mathrm{ref}} .
\]

The center correction uses only the period curve. Duty cycle is not used during center correction, because it is the physical result to be compared after correction.

## Outputs

For each device:

```text
processed_data/<batch>/<device>/
figures/<batch>/<device>/
```

For the whole batch:

```text
processed_data/<batch>/batch_summary_<batch>.csv
figures/<batch>/Batch_summary_<batch>.png
```

## Typical Run

```matlab
cd('D:\GitHub\PFM_poling_analysis')

main_pick_initial_centers_for_batch
main_analyze_batch
```

To switch batches, edit only:

```text
local/active_batch_config.m
```
