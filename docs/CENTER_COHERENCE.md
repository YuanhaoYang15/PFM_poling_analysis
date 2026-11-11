# Inphase center finding and review

Run `main_generate_metadata_from_raw_folder`, check the design radius and
period in `metadata/designs.csv`, then run `main_analyze_inphase_batch`.
Manual picking is optional. The default uses a picked center when one is
available and finds a center automatically otherwise. Inspect the center QC
sheet and flagged list before interpreting duty. For a flagged or visibly
wrong scan, run `main_select_scans_for_rework`,
`main_pick_centers_selected`, and `main_analyze_inphase_selected`.

## Method

The design period grows linearly with radius:
`Lambda(r) = LambdaRef * r / Rref`. Its angular harmonic is therefore
`N = 2*pi*Rref/LambdaRef`. For a candidate center the method subtracts the
weighted mean inphase signal in the analysis annulus, measures its complex
amplitude at this harmonic, and normalizes by the weighted signal energy.
The resulting stripe coherence is high when the observed domains have the
design angular spacing and point toward the candidate center. Duty is not
part of this objective.

Without a picked start, a global search places candidates around the image
center over the full circle, with distances around the design radius. It
uses a block-averaged image. The global peak ratio compares the winning
coherence with the strongest candidate outside its neighborhood. The method
then searches a Cartesian coarse grid at full resolution, recenters the
window if necessary, searches a fine grid, and finishes with `fminsearch`.
A picked start skips the global stage, so its peak ratio is unavailable.

Radial polish checks the signed median period error at trial shifts toward
the observed annulus. For a trial shift `t`, it estimates a zero crossing
as `z(t) = t - error(t)/(LambdaRef/Rref)`. It applies the median estimated
crossing only when enough trial samples are valid, their crossings agree,
and the proposed shift is inside the sampled range. This avoids moving the
center to follow an isolated missing domain. A skipped polish is an
informational note; final coherence and period checks determine whether
review is required.

The legacy grid remains selectable:

```matlab
cfg.centerInit.method = 'manual';
cfg.centerOpt.method = 'grid';
```

This searches centers by period error and keeps its existing edge
refinement. Setting `centerInit.method = 'auto'` with the grid first finds
a coherence start when no picked center is selected. The phase workflow
keeps its existing center handling.

## Reading the QC sheet

The runner saves `Batch_center_qc_<batch>_inphase.png` under
`results/inphase/figures/`. Batches needing multiple pages use `_p1.png`,
`_p2.png`, and so on. Each page holds at most twelve scans in three rows
and four columns, including reused results.

Each tile unwraps the inphase image about its final center. The horizontal
axis is arc length at the design radius, measured from the middle of the
visible arc. The vertical axis is radius, extending beyond the analysis
range for context. White lines bound the waveguide; magenta dashed lines
bound the analysis range. Dotted vertical lines have the design period at
the design radius and are shifted using the fitted angular harmonic phase
at the final center. Correctly centered radial stripes should remain
vertical and follow the dotted lines through the radial range. Bending or
systematic drift calls for review even when no automatic flag is present.

Titles show the raw name, center source and method, final coherence, global
peak ratio, and signed median period error. Flagged titles are red and
include reasons. NaN means that a quantity is unavailable, for example a
global peak ratio after a picked start or coherence diagnostics from the
legacy grid. A flagged period error can indicate missing or irregular
domains even when the center looks correct; manually picking a different
center does not necessarily resolve it.

The batch summary CSV appends `centerSource`, `centerMethod`,
`centerCoherence`, `centerPeakRatio`, `centerPeriodError_um`, `centerFlag`,
and `centerFlagReason`. Results save the corresponding `centerQC` record,
including informational `notes`. The console lists flagged scans, and
`progress.log` contains a `CENTER_QC FLAG` line for each. The rework selector
marks flagged rows and suggests their indices.

## Flags and actions

| Condition with default settings | Interpretation and next step |
| --- | --- |
| Click-free global peak ratio below `1.2` | Competing center locations have similar scores. Inspect the sheet and use a picked start if the selected location is wrong. |
| Final stripe coherence below `0.45` | Stripes do not strongly match the design harmonic. Check signal quality, design metadata, and stripe alignment. |
| Local search still at its window edge | The search may not have reached the best neighborhood. Check or repick the start, or increase the selected local range. |
| Final period evaluation invalid | Too few radii pass the configured validity filters. Inspect the domains, analysis range, and extraction. |
| Absolute final signed median period error above `0.03 um` | The final spacing disagrees with design. Check design metadata and look for missing domains before changing the center. |

The legacy grid flags a nonempty boundary warning. Its coherence and global
peak ratio are NaN. A skipped radial polish alone does not flag a coherence
result; its reason appears in `centerQC.notes`.

## Configuration reference

Set options in the active batch config. Defaults below come from
`set_default_batch_options`; an existing batch config may override them.
All distances and radii are in micrometres. The design geometry and radial
extraction range come from the batch metadata.

| Option | Default | Meaning |
| --- | --- | --- |
| `centerInit.method` | `'auto'` | `'auto'` permits a click-free start; `'manual'` errors when no initial center exists. |
| `centerInit.preferManual` | `true` | In auto mode, use a stored or metadata center when available; `false` always starts globally. |
| `centerOpt.enable` | `true` | Refine the selected start. If false, use the picked start, or the automatic coherence center without radial polish. |
| `centerOpt.method` | `'coherence'` | `'coherence'` or the legacy `'grid'`. |

Initial-center lookup checks the scan metadata center first, then the batch
picked-center table, then the legacy device table. The result source is
`manual` for any of these supplied centers and `auto` for a click-free
start. `centerMethod` is `fixed` when optimization is disabled. For a
click-free coherence result, `centerInitial` is the coherence center before
radial polish, and `centerShift` measures the polish displacement. With a
picked start, the shift is relative to that start.

The following fields are under `cfg.centerOpt.coherence`:

| Field | Default | Meaning |
| --- | --- | --- |
| `radiusRange` | `[]` | Use `[radius.rMin, radius.rMax]`; otherwise set the coherence annulus explicitly. |
| `taper_um` | `0.5` | Width of the soft annulus-edge weighting. |
| `minPixels` | `2000` | Minimum supported finite pixels; scaled for global decimation. |
| `globalDistanceHalfRange_um` | `[]` | Half the image diagonal when empty. |
| `globalDistanceStep_um` | `0.5` | Global candidate distance spacing. |
| `globalTangentialStep_um` | `1.75` | Approximate global tangential spacing at the design radius. |
| `globalDecimate` | `2` | Image block-averaging factor for the global stage. |
| `localRange_um` | `5.0` | Coarse grid half range from a supplied center; after global search the half range is `3.0`. |
| `coarseStep_um` | `0.5` | Coarse grid spacing. |
| `fineRange_um` | `0.75` | Fine grid half range. |
| `fineStep_um` | `0.125` | Fine grid spacing. |
| `minPeakRatio` | `1.2` | Review threshold for global ambiguity. |
| `minCoherence` | `0.45` | Review threshold for final coherence. |
| `maxFinalPeriodError_um` | `0.03` | Review threshold for absolute final signed median period error. |

The global peak comparison excludes candidates within both `4 um` in
distance and `7 um` in tangential separation at the design radius. The
coarse window permits three recenterings after its first pass. The final
`fminsearch` uses `TolX = 1e-3 um` and `TolFun = 1e-8`.

The following fields are under `cfg.centerOpt.radialPolish`:

| Field | Default | Meaning |
| --- | --- | --- |
| `enable` | `true` | Sample the radial period response and conditionally apply its zero crossing. |
| `range_um` | `0.6` | Symmetric trial-shift half range. |
| `step_um` | `0.05` | Trial-shift spacing. |
| `minSamples` | `5` | Minimum number of finite crossing estimates. |
| `agreeTolerance_um` | `0.10` | Maximum deviation from the median crossing for an agreeing sample. |
| `minAgreeFraction` | `0.5` | Required agreeing fraction of all trial samples, including invalid ones. |

The period evaluation and legacy grid share these `cfg.centerOpt` fields:

| Field | Default | Meaning |
| --- | --- | --- |
| `fitRadiusRange` | `[]` | Waveguide band when empty, clipped to the analysis range. |
| `rStep` | `0.10` | Radius spacing for center period evaluation. |
| `minValidRadii` | `3` | Minimum accepted radii. |
| `minNPeriods` | `2` | Minimum complete periods at each accepted radius. |
| `maxPeriodStd_um` | `Inf` | Maximum within-radius period standard deviation. |
| `maxAbsPeriodError_um` | `Inf` | Maximum within-radius absolute design error. |
| `metricMode` | `'median_abs'` | Reported legacy metric: median absolute error; also supports `rmse` and `mean_abs`. Radial polish uses signed median error for its crossing. |
| `searchRange` | `1.0` | Legacy grid half range. |
| `searchStep` | `0.05` | Legacy grid spacing. |

Legacy edge refinement is controlled by `centerOpt.edgeRefine.enable`
(`true`), `maxPasses` (`2`), `rangeScale` (`0.5`), `outwardFraction` (`0.75`),
and `boundaryStepTolerance` (`1.0`). A boundary minimum triggers the smaller
outward-biased second pass; another outward boundary hit requests review.
The selected-scan `centerSearchRange_um` override sets both the legacy
`searchRange` and the coherence `localRange_um`.

`cfg.run.skipExisting` defaults to `true`; `forceReprocess` defaults to
`false`. Changing the center options does not invalidate saved results.
Use selected reanalysis for specific scans or explicitly request a full
reprocess. Older results without center QC are reused with empty source,
method, and reason labels, NaN diagnostics, and `centerFlag = false`;
absence of a historical flag is not a retrospective quality assessment.

## Arc seam and numerical changes

Arc extraction joins visible runs that meet across `theta = -pi` and
`theta = pi`, keeps the shared physical endpoint once, and unwraps theta
and arc length monotonically. Previously, only the longer of the split
pieces was used. Arcs that do not cross this seam and fully visible circles
retain their previous extraction values at the same center. Changing the
center can still change their extracted period and duty.

Reanalyzing an existing batch with the new defaults therefore changes its
numbers: scans whose arc crossed the seam gain periods, and every center
moves to the coherence result. `tests/run_center_regression.m` compares the
new centers and duty with saved results of the previous pipeline for the
batches available locally and writes the per-scan table to
`local/regression_out/center_regression.csv`, which is not tracked. Two
start modes that agree closely do not by themselves establish signal
quality; use the flags and the QC sheet for that.

Run `test_arc_seam`, `test_center_coherence_synthetic`, and
`run_center_regression` from `tests/` for numerical checks. The real-data
regression supports `run_center_regression(20)` to process the scans in
successive chunks. `test_inphase_runner_modes` checks the batch integration,
reuse, manual rework, legacy selection, and flag propagation in isolated
test batches.

For shorter MATLAB sessions, the integration test can retain its checks and
state across calls:

```matlab
test_inphase_runner_modes(1, 't02_runner_state.mat')
test_inphase_runner_modes(2, 't02_runner_state.mat')
test_inphase_runner_modes(3:6, 't02_runner_state.mat')
```

The state file stays in `local/test_configs/`; choose a new name for a fresh
test. Partial calls print `PENDING`. The final `PASS` requires every case to
have run and passed, and failures remain recorded across calls.
