# PFM Poling Analysis

MATLAB toolkit for batch analysis of PFM scans from circularly poled devices.

The project is designed for the real experimental workflow:

```text
one batch
→ multiple design types
→ multiple devices
→ multiple PFM scans per device
→ center correction
→ period/duty-cycle extraction
→ scan/device/batch summaries
```

Raw PFM data should stay outside this code repository.

---

## 1. First-time setup

Copy:

```matlab
local/local_paths_template.m
```

to:

```matlab
local/local_paths.m
```

Then set your external raw-data roots, for example:

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
function cfg = active_batch_config()
cfg = config_batch_20260511();
end
```

Both `local_paths.m` and `active_batch_config.m` are ignored by Git.

---

## 2. Recommended workflow

For a new or updated batch:

```matlab
main_generate_metadata_from_raw_folder
main_pick_initial_centers_for_batch
main_analyze_batch
```

For reworking selected scans:

```matlab
main_select_scans_for_rework
main_pick_centers_selected      % only needed if repicking centers
main_analyze_selected
```

To clear the selected-scan list:

```matlab
main_clear_selected_scans
```

---

## 3. Metadata files

Each batch is controlled by three CSV files:

```text
metadata/designs_<batchName>.csv
metadata/devices_<batchName>.csv
metadata/scans_<batchName>.csv
```

### designs CSV

Defines geometry/design parameters:

```text
designID,R0_um,w_um,Rref_um,LambdaRef_um,rMin_um,rMax_um,dr_um,...
```

### devices CSV

Defines device-level information and notes:

```text
deviceID,designID,polingGroup,polingVoltage,polingTime,row,col,notes
```

The `notes` column is displayed in the right-side notes panel of the batch summary figure.

### scans CSV

Defines scan-level raw file mapping:

```text
deviceID,scanID,rawName,phaseFilePattern,positionLabel,centerX_um,centerY_um,notes
```

Usually `centerX_um` and `centerY_um` are left empty, and centers are picked with:

```matlab
main_pick_initial_centers_for_batch
```

---

## 4. Main outputs

For each device:

```text
processed_data/<batchName>/<deviceID>/
figures/<batchName>/<deviceID>/
```

For the whole batch:

```text
processed_data/<batchName>/batch_summary_<batchName>.csv
figures/<batchName>/Batch_summary_<batchName>.png
```

The `.fig` files are saved in a visible state, so double-clicking them in MATLAB should open them normally.

---

## 5. Analysis principle

For a circularly poled device with angular period `Delta theta`, the designed period along radius `r` is:

```text
Lambda_design(r) = r * Delta theta
```

If the designed period is known at reference radius `Rref`:

```text
Lambda_design(r) = LambdaRef * r / Rref
```

The period curve is used for center correction. Duty cycle is extracted after the center is determined.

---

## 6. Git hygiene

Do not commit raw data or generated outputs.

Ignored by default:

```text
raw_txt/*
raw_data/*
processed_data/*
figures/*
local/local_paths.m
local/active_batch_config.m
local/initial_centers_*.mat
local/initial_centers_*.csv
local/selected_scans_batch_*.csv
```
