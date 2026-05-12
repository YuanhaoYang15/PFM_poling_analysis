# PFM Poling Analysis — AI Context

> Purpose: give a future AI assistant or collaborator enough context to continue this project without reading the full chat history.  
> Suggested location in repo: `docs/AI_CONTEXT.md`.

---

## 1. Project goal

This MATLAB project analyzes PFM scans of circularly poled devices.

The real experimental workflow is:

```text
one experimental batch
→ multiple design types
→ multiple devices
→ multiple PFM scans per device
→ center finding/correction
→ period and duty-cycle extraction
→ scan/device/batch summary plots
```

The user often measures many nominally similar devices with different poling parameters and/or different geometry. Each device can have multiple scans, typically named with suffixes such as `_1`, `_2`.

The project should support iterative work:

```text
measure some data
→ analyze batch
→ inspect plots
→ select problematic scans
→ repick/reanalyze only those scans
→ add more raw data later
→ analyze only new data
→ regenerate summaries
```

---

## 2. Repository and privacy model

GitHub repo:

```text
https://github.com/YuanhaoYang15/PFM_poling_analysis
```

The user may keep this repo public. Therefore the repo should contain only code, docs, templates, and empty placeholders.

Do not commit:

```text
raw data
processed data
generated figures
metadata CSV files with experiment details
local machine paths
initial center files
selected scan CSVs
MATLAB .mat / .fig output files
```

Recommended public folders:

```text
config/
functions/
docs/
local/
metadata/
raw_txt/
raw_data/
processed_data/
figures/
```

Folders such as `metadata`, `raw_txt`, `raw_data`, `processed_data`, and `figures` should only contain `.gitkeep` or README placeholders in the public repo.

---

## 3. Main workflow

### Normal batch workflow

```matlab
main_generate_metadata_from_raw_folder
main_pick_initial_centers_for_batch
main_analyze_batch
```

Expected behavior:

```text
main_generate_metadata_from_raw_folder
    scans raw folder
    parses filenames
    generates/merges metadata CSVs

main_pick_initial_centers_for_batch
    skips scans with existing centers
    opens only missing/new scans
    uses radial-line center picking

main_analyze_batch
    loads existing processed results
    analyzes only missing/new scans
    regenerates summaries and figures
```

### Selected-scan rework workflow

```matlab
main_select_scans_for_rework
main_pick_centers_selected      % only if repicking centers
main_analyze_selected
```

`main_select_scans_for_rework` should automatically create:

```text
local/selected_scans_batch_<batchName>.csv
```

The user should not need to manually create selected-scan CSV files.

Clear selected-scan list:

```matlab
main_clear_selected_scans
```

---

## 4. Batch selection and local paths

The active batch is selected in:

```text
local/active_batch_config.m
```

Example:

```matlab
function cfg = active_batch_config()
cfg = config_batch_20260511();
end
```

Current pain point: each new batch folder such as `20260511_1` requires adding a path in `local/local_paths.m`.

Recommended future improvement: support a single parent raw-data directory.

Example local paths:

```matlab
function paths = local_paths()

paths = struct();

paths.rawParent = ...
    'D:\Project\NUS\Project\Single Photon Nonlinearity\Image';

paths.outputRoot = '';

end
```

Recommended raw-root priority:

```text
1. localPaths.rawRoots.batch_<batchName>, if explicitly defined
2. fullfile(localPaths.rawParent, cfg.batchName), if rawParent exists
3. localPaths.rawTxtRoot, legacy fallback
4. fullfile(projectRoot, 'raw_txt', cfg.batchName), repo fallback
```

This would let a config with

```matlab
cfg.batchName = '20260511_1';
```

automatically map to:

```text
D:\Project\NUS\Project\Single Photon Nonlinearity\Image\20260511_1
```

---

## 5. Metadata files

### Designs metadata

```text
metadata/designs_<batchName>.csv
```

Important columns:

```text
designID
R0_um
w_um
Rref_um
LambdaRef_um
rMin_um
rMax_um
dr_um
scanSizeX_um
scanSizeY_um
notes
```

Meaning:

```text
R0_um          waveguide center radius
w_um           waveguide width
Rref_um        reference radius for design period
LambdaRef_um   designed period at Rref
rMin_um        minimum analysis radius
rMax_um        maximum analysis radius
dr_um          radius step
```

Designed period curve:

```text
Lambda_design(r) = LambdaRef_um * r / Rref_um
```

If a design has `R0 = 40 um` and designed period at that radius is `3.0 um`, use:

```text
Rref_um = 40
LambdaRef_um = 3.0
```

### Devices metadata

Device metadata has been simplified. Use only:

```text
deviceID, designID, row, col, notes
```

Do not use separate `polingGroup`, `polingVoltage`, or `polingTime` columns. The lab has its own poling-record format, so the user writes poling parameters directly into `notes`.

Example:

```csv
deviceID,designID,row,col,notes
UF_2p5_r1c1,UF_2p5,1,1,Size A; poling: lab-format condition here
UF_2p5_r1c2,UF_2p5,1,2,Size A; poling: condition B
```

These notes are displayed in the right-side notes panel of the batch summary figure.

### Scans metadata

```text
metadata/scans_<batchName>.csv
```

Typical columns:

```text
deviceID
scanID
rawName
phaseFilePattern
positionLabel
centerX_um
centerY_um
notes
```

Usually `centerX_um` and `centerY_um` are empty and are filled by the center-picking workflow.

---

## 6. Filename parsing and metadata generation

The user’s common raw filenames look like:

```text
UF_2p5_r1c1_1.txt
UF_2p5_r1c1_2.txt
```

The parser should extract:

```text
prefix  = UF_2p5
row     = 1
col     = 1
scanID  = 1 or 2
deviceID = UF_2p5_r1c1
rawName  = UF_2p5_r1c1_1
```

Typical config:

```matlab
cfg.naming.rawFilePattern = '^(?<prefix>.+)_r(?<row>\d+)c(?<col>\d+)_(?<scanID>\d+)$';
cfg.naming.rawFileExt = '.txt';
cfg.naming.deviceIDFormat = '%s_r%dc%d';
cfg.naming.designIDFromPrefix = true;
```

Metadata generation should merge rather than overwrite:

```text
existing metadata rows are preserved
new raw files are appended
manual notes are preserved
missing raw files are not deleted automatically
```

---

## 7. Raw data reader

Use the legacy NanoScope ASCII reader. This was chosen because a generic automatic importer caused errors by misidentifying the text format as scattered XYZ, matrix-only data, or flattened multi-column data.

Stable logic:

```matlab
[D, info, raw] = read_pfm_txt_nanoscope_legacy(filePath, cfg);
phase = D.LS_PR_Phase;
x_um = linspace(0, info.scanX_um, info.nx);
y_um = linspace(0, info.scanY_um, info.ny);
Z = reshape(v, [nx, ny]).';
```

Default config:

```matlab
cfg.preprocess.reader = 'nanoscope_legacy';
cfg.preprocess.phaseField = 'LS_PR_Phase';
```

Avoid reverting to a generic raw-format guessing importer.

---

## 8. Center finding and correction

### Manual initial center

Best method: `manual_radial_lines`.

Concept:

```text
click two points on each radial domain line
→ each pair defines a radial line
→ fit least-squares intersection of all radial lines
→ use as initial center
```

This is much more robust than single-click approximate center picking.

Config:

```matlab
cfg.centerPicker.method = 'manual_radial_lines';
cfg.centerPicker.skipExisting = true;
```

### Period-based center correction

After manual center, refine center using the design period curve.

Important config:

```matlab
cfg.centerOpt.enable = true;
cfg.centerOpt.searchRange = 1.0;
cfg.centerOpt.searchStep  = 0.05;
cfg.centerOpt.fitRadiusRange = [];
```

Meaning:

```text
searchRange    max x/y center shift around initial center
searchStep     center-search grid step
fitRadiusRange radius range used for period-based correction
```

If `fitRadiusRange = []`, use waveguide region:

```text
[R0 - w/2, R0 + w/2]
```

Example larger search:

```matlab
cfg.centerOpt.searchRange = 2.0;
cfg.centerOpt.searchStep = 0.05;
cfg.centerOpt.fitRadiusRange = [29.5, 30.5];
```

Do not blindly use the full `[rMin, rMax]` range because bad outer-radius points can pull the optimization off.

---

## 9. Period and duty-cycle extraction

Use legacy extraction logic:

```text
interpolate cos(phase) and sin(phase), not raw wrapped phase
reconstruct phase along circular arc
smooth on unit circle
classify two PFM states using 2D k-means on [cos(phi), sin(phi)]
compute duty cycle and period from binary trace
```

Typical config:

```matlab
cfg.extract.phaseSmoothWin  = 9;
cfg.extract.binarySmoothWin = 7;
cfg.extract.minSegmentPts   = 3;
cfg.extract.minPeriodUm = 1.0;
cfg.extract.maxPeriodUm = 5.0;
```

---

## 10. Incremental analysis behavior

`main_analyze_batch` should be incremental.

Expected logic:

```text
if processed result exists and skipExisting = true:
    load existing result
else:
    analyze raw scan
```

Config:

```matlab
cfg.run.skipExisting = true;
cfg.run.forceReprocess = false;
cfg.run.regenerateFiguresForExisting = false;
```

If only plotting changed and the user wants to regenerate figures:

```matlab
cfg.run.regenerateFiguresForExisting = true;
```

If design parameters or extraction parameters changed and results must be recomputed:

```matlab
main_select_scans_for_rework
main_analyze_selected
```

or temporarily:

```matlab
cfg.run.forceReprocess = true;
```

Then revert:

```matlab
cfg.run.forceReprocess = false;
```

Important bug fix: ordinary `main_analyze_batch` should ignore selected scans. Only `main_analyze_selected` should read and apply selected-scan overrides.

In `run_batch_analysis.m`, normal mode should use:

```matlab
if selectedOnly
    selectedTable = get_selected_scan_table(batchCfg, true);
else
    selectedTable = table();
end
```

And selected overrides should only be applied when `selectedOnly == true`.

---

## 11. Selected-scan rework

The user should not manually create selected-scan CSV files.

`main_select_scans_for_rework` should:

```text
read processed_data/<batch>/batch_summary_<batch>.csv
print scan indices, deviceID, scanID, rawName, period error, duty mean, center shift
ask for indices, e.g. [2 5 10]
ask action:
    1 = repick_center
    2 = reanalyze
    3 = larger_search
    4 = custom_fit_range
write local/selected_scans_batch_<batchName>.csv
```

Then:

```matlab
main_pick_centers_selected
main_analyze_selected
```

or if no center repick is needed:

```matlab
main_analyze_selected
```

---

## 12. Plotting requirements

### Figure saving

A bug occurred where `.fig` files saved from invisible figures reopened invisibly. Use:

```matlab
save_analysis_figure(fig, pngPath, cfg)
```

This temporarily sets `Visible = 'on'` before `savefig`.

### Batch plotting mode

For batch processing:

```matlab
cfg.plot.showFigures = false;
cfg.plot.saveFigures = true;
cfg.plot.closeAfterSave = true;
cfg.plot.figureWindowStyle = 'normal';   % or 'docked'
```

Interactive center picking still needs visible figures.

### Period plot limits

Use design curve ± 1 um:

```matlab
cfg.plot.periodYLimMode = 'design_pm';
cfg.plot.periodYLimHalfRange = 1.0;
cfg.plot.periodErrorYLimHalfRange = 1.0;
```

### All-scan comparison legend

The all-scan comparison figure should include:

```text
scan 1
scan 2
design
WG region
```

The black dashed design curve should not be missing from the legend.

### Batch summary notes panel

The batch summary should use a right-side notes panel instead of a floating textbox inside a subplot.

Panel content:

```text
SCAN INDEX
----------
1: deviceID-scanID
2: deviceID-scanID

DEVICE NOTES
------------
deviceID | designID | r#c#
  notes from devices CSV
```

---

## 13. Current root scripts

Recommended scripts to keep:

```text
main_generate_metadata_from_raw_folder.m
main_simplify_device_metadata.m
main_pick_initial_centers_for_batch.m
main_analyze_batch.m
main_select_scans_for_rework.m
main_pick_centers_selected.m
main_analyze_selected.m
main_clear_selected_scans.m
```

Legacy/debug scripts that can be moved to `docs/legacy/` or deleted after confirmation:

```text
main_analyze_one_device.m
main_analyze_all_devices.m
main_pick_initial_centers.m
main_debug_one_raw_scan.m
```

---

## 14. Common user questions

### Where do I change radius and design period?

Edit:

```text
metadata/designs_<batchName>.csv
```

Change:

```text
R0_um
w_um
Rref_um
LambdaRef_um
rMin_um
rMax_um
dr_um
```

If scans were already analyzed, reprocess selected scans or force reprocess.

### Where do I change center shift range?

Edit batch config:

```matlab
cfg.centerOpt.searchRange = 1.5;
cfg.centerOpt.searchStep  = 0.05;
```

### Where do I write device notes?

Edit:

```text
metadata/devices_<batchName>.csv
```

Use the `notes` column.

### How do I add new raw data to an existing batch?

Put new raw txt files into the raw folder, then run:

```matlab
main_generate_metadata_from_raw_folder
main_pick_initial_centers_for_batch
main_analyze_batch
```

### How do I rework bad scans?

```matlab
main_select_scans_for_rework
main_pick_centers_selected
main_analyze_selected
```

---

## 15. Near-term TODOs

1. Add `rawParent` logic so new batch folders do not require manually adding raw paths.
2. Verify `main_analyze_batch` ignores selected-scan overrides in normal mode.
3. Add optional `main_compare_batches` for comparing:
   ```text
   20260511
   20260511_1
   20260511_2
   ```
4. Clean public repo: keep code/templates/docs, ignore metadata CSVs and all experimental data.
5. Move legacy scripts to `docs/legacy/` or delete.
6. Create first release tag, e.g. `v1.0.0`.

---

## 16. Most important design decisions

Stable workflow:

```text
legacy NanoScope reader
+ radial-line manual center
+ controlled period-based center correction
+ legacy period/duty extraction
+ incremental batch processing
+ selected-scan rework
+ simplified device metadata
```

Avoid reverting to:

```text
generic raw-format guessing
single-click center picking
manual creation of selected scan CSV
metadata with too many fixed poling columns
```

The project should behave like an experimental data pipeline, not a one-shot plotting script.
