# Patch v8: Incremental batch workflow and controlled center correction

Copy/replace the files in this patch into the repository root.

## New workflows

### 1. Generate metadata from raw folder
```matlab
main_generate_metadata_from_raw_folder
```
This scans the active batch raw folder, parses filenames like `UF_2p5_r1c5_2.txt`, and merges new rows into the metadata CSVs.

### 2. Pick centers
```matlab
main_pick_initial_centers_for_batch
```
Skips existing centers by default.

### 3. Analyze incrementally
```matlab
main_analyze_batch
```
Loads existing processed results and only analyzes new/missing scans by default.

### 4. Repair selected scans
Create:
```text
local/selected_scans.csv
```
with at least:
```csv
deviceID,scanID
UF_2p5_r1c5,2
```
Then run:
```matlab
main_pick_centers_selected
main_analyze_selected
```

## Per-scan overrides
Add optional columns to `metadata/scans_<batch>.csv` only for troublesome scans:

```csv
centerOptEnable,centerSearchRange_um,centerSearchStep_um,centerFitRMin_um,centerFitRMax_um,forceReprocess,phaseSmoothWin,binarySmoothWin,minSegmentPts
```

Empty cells use the batch defaults.
