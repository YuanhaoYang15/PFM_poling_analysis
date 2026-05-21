# Repository cleanup checklist for v1.0

This repo is a batch-level PFM analysis toolkit. Private batch data belongs
under `local/batches/<batchName>/` or under the private `batchParent`
configured in `local/local_paths.m`.

## Keep

Root scripts:

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
```

Tracked folders:

```text
config/
functions/
docs/
local/
```

Tracked local templates:

```text
local/README.md
local/local_paths_template.m
local/active_batch_config_template.m
```

## Current private batch tree

```text
local/batches/<batchName>/
  raw/
  metadata/
  centers/
  selected_scans/
  results/inphase/
  results/phase/
```

Root-level `raw_txt/`, `raw_data/`, `metadata/`, `processed_data/`, and
`figures/` are not public layout folders anymore. They remain ignored if an
older workflow recreates them.

## Do not commit

```text
local/batches/*
local/local_paths.m
local/active_batch_config.m
raw experimental files
metadata CSVs with experiment details
picked center files
selected-scan CSVs
processed .mat files
generated figures and logs
```

## Optional legacy cleanup

Single-device or debug scripts that reappear from older branches should be
deleted or archived after confirming they are not needed:

```text
main_analyze_one_device.m
main_analyze_all_devices.m
main_pick_initial_centers.m
main_debug_one_raw_scan.m
config/config_E7_R1C2.m
config/config_template.m
```
