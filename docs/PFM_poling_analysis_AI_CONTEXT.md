# PFM Poling Analysis - AI Context

This file is a compact handoff for future work on the repo. The codebase
is a MATLAB batch workflow for circular PFM poling analysis.

## Current architecture

The tracked repo contains code, docs, templates, and batch configs. Private
experimental state belongs in a batch-local tree:

```text
local/batches/<batchName>/
  raw/
  metadata/
    designs.csv
    devices.csv
    scans.csv
  centers/
    initial_centers_batch_<batchName>.mat
    initial_centers_batch_<batchName>.csv
  selected_scans/
    selected_scans.csv
  results/
    inphase/
      processed_data/
      figures/
      progress.log
    phase/
      processed_data/
      figures/
```

Root-level `raw_txt`, `raw_data`, `metadata`, `processed_data`, and
`figures` folders are legacy names only. They are ignored if recreated and
are not part of the public layout.

`configure_local_batch_paths` sets the batch-local path tree. Batch configs
should call it after `cfg.paths.projectRoot` and `cfg.batchName` are set.

## Signal roles

Phase and inphase are different signal bases for the same experimental
batch.

- Inphase is the preferred basis for duty-cycle extraction.
- Phase remains available for observation, comparison, and optional
  phase-based extraction.
- Manual center picking, automatic center optimization, and final duty
  extraction are distinct decisions and should remain explicit.

The inphase workflow writes saved result fields such as:

```text
signalField = LS_PR_Inphase
dutyDefinition = low_inphase
```

The phase workflow keeps the existing phase result conventions.

## Main root scripts

Keep these public entry points:

```text
main_generate_metadata_from_raw_folder.m
main_pick_initial_centers_for_batch.m
main_analyze_inphase_batch.m
main_analyze_inphase_selected.m
main_analyze_batch.m
main_select_scans_for_rework.m
main_pick_centers_selected.m
main_analyze_selected.m
main_clear_selected_scans.m
main_plot_batch_duty_notes.m
main_simplify_device_metadata.m
```

## Local setup

Tracked templates live in `local/`:

```text
local/local_paths_template.m
local/active_batch_config_template.m
```

Copy them to ignored local files:

```text
local/local_paths.m
local/active_batch_config.m
```

`local_paths.m` may set:

```matlab
paths.batchParent = fullfile(projectRoot, 'local', 'batches');
paths.batchRoots.batch_20260521_3 = 'D:\private\PFM_batches\20260521_3';
```

`active_batch_config.m` returns the config used by root scripts.

## Normal batch workflow

For the inphase-first workflow:

```matlab
main_generate_metadata_from_raw_folder
main_pick_initial_centers_for_batch
main_analyze_inphase_batch
```

Before center picking, review the generated batch metadata and set radius
and period parameters in:

```text
local/batches/<batchName>/metadata/designs.csv
```

Run the phase workflow only when a phase result is needed:

```matlab
main_analyze_batch
```

## Metadata

`designs.csv` stores design geometry:

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

Designed period is evaluated as:

```text
Lambda_design(r) = LambdaRef_um * r / Rref_um
```

`devices.csv` uses:

```text
deviceID, designID, row, col, notes
```

`scans.csv` maps raw scan names and may contain per-scan overrides:

```text
deviceID
scanID
rawName
phaseFilePattern
positionLabel
centerX_um
centerY_um
notes
rMin_um
rMax_um
dr_um
centerOptEnable
centerSearchRange_um
centerSearchStep_um
centerOptRStep_um
centerFitRMin_um
centerFitRMax_um
```

Interactive center picking usually stores centers in the batch `centers/`
folder instead of editing center columns in `scans.csv`.

## Filename parsing

Metadata generation scans the active batch `raw/` folder and merges rows
instead of overwriting manual metadata.

A common lowercase parser pattern is:

```matlab
cfg.naming.rawFilePattern = '^(?<prefix>.+)_r(?<row>\d+)c(?<col>\d+)_(?<scanID>\d+)$';
```

Some recent UR batches use uppercase raw names such as `UR_R4C1_2` and set
their own uppercase parser pattern in the batch config.

## Center picking and optimization

Initial centers are picked manually, normally from radial domain lines.
`cfg.centerPicker.displaySignal` may be `phase` or `inphase`.

Center optimization must use period error only. Duty is measured after
center correction.

The inphase optimizer currently has an edge refinement strategy:

```text
pass 1:
  search around the manual center

if best x or y offset is within one search step of the pass-1 boundary:
  pass 2:
    anchor at the pass-1 best center
    use a smaller search range
    bias the touched axis toward the unexplored outward side

if pass 2 still touches the outward side:
  warn that the manual center should be reviewed
```

Default refinement parameters are stored under:

```matlab
cfg.centerOpt.edgeRefine.enable = true;
cfg.centerOpt.edgeRefine.maxPasses = 2;
cfg.centerOpt.edgeRefine.rangeScale = 0.5;
cfg.centerOpt.edgeRefine.outwardFraction = 0.75;
cfg.centerOpt.edgeRefine.boundaryStepTolerance = 1.0;
```

The final `centerShift` is always reported relative to the original manual
center. Per-pass optimizer details are saved under `result.centerOpt.passes`.

The inphase batch runner reports current file, stage, and center search
progress to the console and batch `results/inphase/progress.log`.

## Selected-scan rework

Use the selector instead of hand-writing the selected-scan CSV:

```matlab
main_select_scans_for_rework
```

It asks whether the list should come from the inphase or phase batch
summary, then writes:

```text
local/batches/<batchName>/selected_scans/selected_scans.csv
```

Then run:

```matlab
main_pick_centers_selected        % only when repicking centers
main_analyze_inphase_selected     % selected inphase reanalysis
main_analyze_selected             % selected phase reanalysis
```

Selected-only analysis reprocesses selected scans, reuses existing results
for non-selected scans, and rebuilds summaries.

## Privacy and Git hygiene

Do not commit:

```text
raw experimental data
generated metadata CSV files
picked center files
selected-scan CSV files
processed MAT files
figures
logs
copied local paths or active batch files
```

The public repo should stay small enough to merge without private data.
