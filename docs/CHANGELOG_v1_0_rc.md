# v1.0 release-candidate changes

## Plot fixes

- Summary titles now use plain `um` in the title to avoid `\mum` appearing literally.
- Period plot y-limits are based on the design curve ± `cfg.plot.periodYLimHalfRange`.
- All-scan comparison legends explicitly include:
  - scan curves
  - black dashed design curve
  - shaded WG region
- Batch summary now has a right-side notes panel instead of a floating textbox.
- Device notes are read from `metadata/devices_<batchName>.csv`.

## Workflow

- Keep using incremental batch workflow.
- Keep using selected-scan rework workflow.
- Update `devices_*.csv` notes/poling columns to enrich the batch-summary notes panel.
