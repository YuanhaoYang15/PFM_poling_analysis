# PFM Poling Analysis - AI Context

This file is a compact handoff for future work on the repo. The codebase
is a MATLAB batch workflow for circular PFM poling analysis.

## Agent operating rules

All Codex/Agent work in this repository must follow the project-level
instructions in `../AGENTS.md`, including its mandatory process, terminal,
and resource cleanup rules. This file provides domain and workflow context;
`../AGENTS.md` is authoritative for agent behavior if the two documents ever
conflict.

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
`tests/` contains seam, synthetic-center, real-data regression, and inphase
runner checks. The center method and user settings are documented in
`CENTER_COHERENCE.md`.

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
main_afm_generate_metadata.m
main_afm_plot_channels.m
main_afm_analyze_batch.m
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

`active_batch_config.m` returns the config used by root scripts. AFM runs
use a separate selector, `local/active_afm_batch_config.m` (copied from
`local/active_afm_batch_config_template.m`).

## Normal batch workflow

For the inphase-first workflow:

```matlab
main_generate_metadata_from_raw_folder
main_analyze_inphase_batch
```

Before analysis, review the generated batch metadata and set radius
and period parameters in:

```text
local/batches/<batchName>/metadata/designs.csv
```

Manual center picking is optional for the inphase workflow. Review
`results/inphase/figures/Batch_center_qc_<batch>_inphase*.png` and the flagged
scan list, then select and pick only flagged or visibly wrong scans for
reanalysis. `main_pick_initial_centers_for_batch` remains available for a
manual first pass.

Run the phase workflow only when a phase result is needed:

```matlab
main_analyze_batch
```

## AFM module

AFM topography is a separate module from the PFM duty-cycle workflow. It
uses its own config family (`config_afm_<batch>.m`), selector
(`local/active_afm_batch_config.m`), and results tree
(`results/afm/{raw_qc,processed_data,figures}`).

Workflow:

```matlab
main_afm_generate_metadata   % metadata/afm_scans.csv (auto columns refreshed,
                             % manual columns preserved)
main_afm_plot_channels       % raw-channel QC heatmaps
main_afm_analyze_batch       % leveling + cross-ridge profile + step heights
```

Key functions:

```text
read_nanoscope_txt_channels   generic NanoScope txt reader; the PFM legacy
                              reader is a thin wrapper with PFM header tokens
load_afm_data                 channels -> X/Y + height + cross-check
detect_afm_waveguide_angle    gradient-orientation histogram -> waveguide axis
afm_farfield_mask             ridge edges, moat minima, far-field masks
level_afm_farfield            linear plane fitted on far-field pixels only
extract_afm_profile           median profile perpendicular to the waveguide
extract_afm_step              ridge top / far field / moat step heights
extract_afm_sidewall          10-90% sidewall angles (median + per slice)
plot_afm_3d_surface           per-scan 3-D surface PNG (vertical exaggeration)
plot_afm_sidewall_qc          angle-definition and angle-vs-slice figures
```

`main_afm_plot_sidewall_qc` regenerates the two sidewall illustration
figures for every included scan from the saved processed MAT files.

The analysis chain is: detect the waveguide angle, level the height with a
plane fitted only on the far-field regions outside the ridge and trenches,
then slice perpendicular to the waveguide. `stepLeft_nm`/`stepRight_nm` are
ridge top minus far field (primary etch depth);
`stepMoatLeft_nm`/`stepMoatRight_nm` are ridge top minus the moat next to
the ridge. `cfg.afm.heightField` defaults to `Height_Sensor`; `Height` is
reported as a cross-check because the two channels are differently
calibrated. Details and the summary column list are in
`docs/AFM_MODULE.md`.

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

The default inphase settings are:

```matlab
cfg.centerInit.method = 'auto';
cfg.centerInit.preferManual = true;
cfg.centerOpt.method = 'coherence';
```

An available picked center starts a local coherence search. Otherwise a
global search finds the design angular harmonic, followed by local search
and a radial signed-period zero-crossing correction. Duty is measured only
after center correction. `centerInit.preferManual = false` forces the global
path; `centerInit.method = 'manual'` requires a picked center. Manual lookup
priority is scan metadata, batch center table, then legacy device table.

Select the legacy grid with `centerOpt.method = 'grid'` and
`centerInit.method = 'manual'`. Its `searchRange`, `searchStep`, and
`edgeRefine` settings retain their existing meaning. `centerOpt.enable =
false` uses the selected initial center as is, finding one by coherence if
needed. The phase workflow and `phase_optimized` center mode retain their
existing behavior. Manual picking uses radial lines;
`cfg.centerPicker.displaySignal` may be `phase` or `inphase`.

Results record `centerSource` (`manual` or `auto`), `centerMethod`
(`coherence`, `grid`, or `fixed`), and `centerQC`. The batch CSV appends
coherence, global peak ratio, signed median period error, flag, and reason
columns. Older saved results get empty labels, NaN numbers, and no flag;
`skipExisting` continues to control reuse. For a click-free coherence run,
`centerInitial` is the coherence center before radial polish; `centerShift`
is relative to that center. For a picked start it is relative to the picked
center.

The inphase batch runner reports current file, stage, and center search
progress to the console and batch `results/inphase/progress.log`, including
`CENTER_QC FLAG` entries. It saves a paginated center QC sheet with unwrapped
inphase stripes, waveguide and analysis bounds, and fitted design lines.
See `CENTER_COHERENCE.md` for flag thresholds and options.

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

When center flags are available, the listing marks them, prints their
reasons, and suggests their indices.

Then run:

```matlab
main_pick_centers_selected        % only when repicking centers
main_analyze_inphase_selected     % selected inphase reanalysis
main_analyze_selected             % selected phase reanalysis
```

Selected-only analysis reprocesses selected scans, reuses existing results
for non-selected scans, and rebuilds summaries and the center QC sheet.
Selected `centerSearchRange_um` also sets the coherence local search range.

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
