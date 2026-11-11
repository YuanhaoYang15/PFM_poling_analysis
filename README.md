# PFM Poling Analysis

MATLAB batch analysis for circular PFM poling scans. The repo extracts
period and duty cycle versus radius, refines device centers from designed
period, and saves scan, device, and batch summaries. An independent AFM
module adds basic surface-topography analysis (leveling, cross-ridge
profiles, ridge-to-floor step heights).

## Current Model

The tracked repo is code-first. Private experimental state lives under
`local/batches/<batchName>/` or under a private batch parent configured in
`local/local_paths.m`.

Inphase and phase are two signal bases for the same batch:

- Inphase is the preferred duty-cycle extraction basis.
- Phase remains available for observation, comparison, and optional
  phase-based extraction.
- Manual center picking, automatic center optimization, and duty extraction
  stay explicit in saved results.

AFM scans are a separate module. They have no device/design/center metadata,
so they use their own config, entry points, and `results/afm/` tree. See
`docs/AFM_MODULE.md`.

## Public Layout

```text
PFM_poling_analysis/
  config/                         batch configs and config template
  functions/                      readers, extraction, center correction, plots
  docs/                           workflow notes
  tests/                          seam, center recovery, regression, runner checks
  local/                          local setup templates and ignored batches
  main_generate_metadata_from_raw_folder.m
  main_plot_raw_heatmaps.m
  main_pick_initial_centers_for_batch.m
  main_analyze_inphase_batch.m
  main_analyze_inphase_selected.m
  main_analyze_batch.m
  main_select_scans_for_rework.m
  main_pick_centers_selected.m
  main_analyze_selected.m
  main_afm_generate_metadata.m
  main_afm_plot_channels.m
  main_afm_analyze_batch.m
```

Root-level raw, metadata, figure, and processed-data folders are not part
of the current layout. The corresponding names remain ignored so private
data is not accidentally committed if an old workflow recreates them.

## Private Batch Layout

```text
local/batches/<batchName>/
  raw/                            raw txt/spm exports for this batch
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
    afm/
      raw_qc/
      processed_data/
      figures/
      progress.log
```

Batch configs call `configure_local_batch_paths`, so raw files, metadata,
picked centers, selected-scan lists, and generated results resolve from the
batch-local tree.

## Local Setup

Copy the tracked templates before running root entry points:

```text
local/local_paths_template.m         -> local/local_paths.m
local/active_batch_config_template.m -> local/active_batch_config.m
```

`local_paths.m` may point batches at an external private folder.
`active_batch_config.m` selects the batch config used by root scripts.
Both copied files are ignored by Git.

## Batch Workflow

Put raw txt/spm exports in the active batch `raw/` folder, then run:

```matlab
main_plot_raw_heatmaps
main_generate_metadata_from_raw_folder
```

`main_plot_raw_heatmaps` is a plot-only raw-channel pass. It writes one PNG
for every matrix in every NanoScope TXT export, plus a per-file overview and
a manifest under `results/raw_qc/`, without wrapping, smoothing, centering,
normalization, or duty analysis.

Review the generated `metadata/designs.csv` and set the radius and designed
period entries. Then run:

```matlab
main_analyze_inphase_batch
```

The default inphase workflow finds centers without manual picking. Inspect
`results/inphase/figures/Batch_center_qc_<batch>_inphase*.png` and the flagged
scan list printed at the end. A picked center, when available, is used as
the starting point. Pick or correct centers only for flagged scans or scans
whose stripes do not line up in the QC sheet, then use the rework workflow.
`main_pick_initial_centers_for_batch` remains available for a manual first
pass.

For the phase workflow:

```matlab
main_analyze_batch
```

## Rework Workflow

`main_select_scans_for_rework` asks whether the scan list should come from
the inphase or phase batch summary and writes the selected list into the
active batch.

```matlab
main_select_scans_for_rework
main_pick_centers_selected        % only when center repicking is needed
main_analyze_inphase_selected     % inphase selected scans
main_analyze_selected             % phase selected scans
```

Selected-only analysis reprocesses selected scans, reuses existing results
for the others, and regenerates device and batch summaries and the center QC
sheet. The selector marks center flags, shows their reasons, and suggests
their row indices.

## AFM Topography Workflow

The AFM module is independent of the PFM metadata. Put NanoScope txt exports
in the active AFM batch `raw/` folder and select the batch in
`local/active_afm_batch_config.m`, then run:

```matlab
main_afm_generate_metadata   % metadata/afm_scans.csv (editable)
main_afm_plot_channels       % raw-channel QC heatmaps
main_afm_analyze_batch       % leveling, profiles, step heights
```

`main_afm_analyze_batch` detects the waveguide orientation, levels the
height with a plane fitted on the far-field regions outside the ridge and
trenches, slices perpendicular to the waveguide, and writes per-scan MAT
files, annotated summary figures, and `afm_summary_<batchName>.csv` with
left/right etch depths (ridge top to far field), moat depths, ridge width,
and quality flags. See `docs/AFM_MODULE.md` for the config and column
reference.

## Metadata

The active batch metadata lives in `local/batches/<batchName>/metadata/`.

`designs.csv` stores design geometry and analysis radii:

```text
designID, R0_um, w_um, Rref_um, LambdaRef_um, rMin_um, rMax_um, dr_um
```

Designed period is evaluated as:

```text
Lambda_design(r) = LambdaRef_um * r / Rref_um
```

`devices.csv` maps devices to designs and stores device notes.
`scans.csv` maps scans to raw file names and optional per-scan overrides.
Interactive center picking normally writes initial centers to `centers/`.

## Center Handling

The inphase defaults are:

```matlab
cfg.centerInit.method = 'auto';
cfg.centerInit.preferManual = true;
cfg.centerOpt.method = 'coherence';
```

Without a picked center, the search starts globally and aligns the inphase
stripes to the design angular period. It then refines the center locally
and applies a radial correction only when the signed period response is
consistent. With a picked center it starts locally. Set
`cfg.centerInit.preferManual = false` to use the global search even when
picked centers exist. Set `cfg.centerInit.method = 'manual'` to require one.

To select the legacy inphase period grid search, set these options in the
active batch config:

```matlab
cfg.centerInit.method = 'manual';
cfg.centerOpt.method = 'grid';
```

The grid uses `cfg.centerOpt.searchRange`, `searchStep`, and `edgeRefine`.
With automatic initialization it can also start from a coherence center.
Disabling `cfg.centerOpt.enable` fixes the picked center, or uses the
automatic coherence center as is when no picked center is selected.

Saved results record `centerSource`, `centerMethod`, and `centerQC`. The
batch CSV includes the coherence, global peak ratio, signed median period
error, flag, and reasons. Progress and flagged scans are also written to
`results/inphase/progress.log`. Existing results are reused according to
`cfg.run.skipExisting`; changing a method does not automatically recompute
them. Older saved results remain readable and have empty center labels and
unavailable QC numbers in the summary.

Duty cycle is interpreted after center correction. It is not the center
optimization objective. The phase workflow keeps its existing center
handling. See [Center coherence](docs/CENTER_COHERENCE.md) for the method,
configuration, QC interpretation, and measured changes from the previous
pipeline.

## Repo Hygiene

Do not commit raw data, generated metadata CSVs, selected-scan CSVs, picked
center files, processed MAT files, generated figures, logs, or copied local
settings. The tracked repo should contain code, docs, templates, and batch
configs only.
