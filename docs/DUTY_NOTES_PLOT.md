# Duty-cycle-only summary plot

This patch adds a presentation-style summary figure:

```text
left  : WG-region mean duty cycle only
right : scan index and device notes
```

## Files

```text
main_plot_batch_duty_notes.m
functions/plot_batch_duty_notes.m
```

## Usage

Run after batch analysis:

```matlab
main_analyze_batch
main_plot_batch_duty_notes
```

## Controllable ylim

In `main_plot_batch_duty_notes.m`, edit:

```matlab
batchCfg.plot.dutyNotesYLim = [0, 1];
```

Examples:

```matlab
batchCfg.plot.dutyNotesYLim = [0.3, 0.8];
batchCfg.plot.dutyNotesYLim = [];
```

## Optional reference line

```matlab
batchCfg.plot.dutyNotesReference = 0.5;
```

Set to `[]` to disable.

## X-axis label mode

```matlab
batchCfg.plot.dutyNotesXLabelMode = 'index';   % 1, 2, 3...
batchCfg.plot.dutyNotesXLabelMode = 'raw';     % rawName
batchCfg.plot.dutyNotesXLabelMode = 'device';  % deviceID-scanID
```

The output is saved as:

```text
figures/<batchName>/Batch_duty_notes_<batchName>.png
```
