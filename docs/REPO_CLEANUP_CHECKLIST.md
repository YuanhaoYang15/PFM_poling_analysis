# Repository cleanup checklist for v1.0

This project is now a batch-level PFM analysis toolkit. The following files are the recommended v1.0 structure.

## Keep

Root scripts:

```text
main_generate_metadata_from_raw_folder.m
main_pick_initial_centers_for_batch.m
main_analyze_batch.m
main_select_scans_for_rework.m
main_pick_centers_selected.m
main_analyze_selected.m
main_clear_selected_scans.m
```

Folders:

```text
config/
functions/
metadata/
local/
docs/
```

Empty placeholder folders are okay:

```text
raw_txt/.gitkeep
raw_data/.gitkeep
processed_data/.gitkeep
figures/.gitkeep
```

## Consider deleting or archiving

These are legacy single-device/debug entry points. Move them to `docs/legacy/` or delete after confirming you no longer use them:

```text
main_analyze_one_device.m
main_analyze_all_devices.m
main_pick_initial_centers.m
main_debug_one_raw_scan.m
```

Legacy config files:

```text
config/config_E7_R1C2.m
config/config_template.m
```

Temporary patch folders/files after merging:

```text
config_patch/
```

## Do not commit

```text
local/local_paths.m
local/active_batch_config.m
local/initial_centers_*.mat
local/initial_centers_*.csv
local/selected_scans_batch_*.csv
processed_data/*
figures/*
raw_txt/*
raw_data/*
```

If any generated files were already tracked by Git, remove them from tracking with:

```bash
git rm -r --cached processed_data figures raw_txt raw_data
git add .gitignore
git commit -m "Stop tracking generated files"
```
