# Device metadata simplification

Device metadata now uses only:

```text
deviceID, designID, row, col, notes
```

Poling parameters should be written directly in `notes` using your lab's preferred format.

Example:

```csv
deviceID,designID,row,col,notes
UF_2p5_r1c1,UF_2p5,1,1,Size A; poling: +300 V 10 s / -300 V 10 s
UF_2p5_r1c2,UF_2p5,1,2,Size A; poling: condition B
```

To convert an existing devices CSV, run:

```matlab
main_simplify_device_metadata
```

After editing notes, regenerate summary figures with:

```matlab
main_analyze_batch
```

If existing results are reused, the script will only regenerate summaries/figures and will not reprocess raw data unless configured.
