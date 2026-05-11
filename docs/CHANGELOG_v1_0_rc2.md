# v1.0-rc2 changes

- Simplified device metadata to:
  - `deviceID`
  - `designID`
  - `row`
  - `col`
  - `notes`
- Removed generation of `polingGroup`, `polingVoltage`, and `polingTime` columns.
- Batch summary notes panel now displays only:
  - device ID
  - design ID
  - row/column
  - notes
- Added `main_simplify_device_metadata.m` to migrate old devices CSV files.
