# Local Data And Settings

This folder stores ignored private batch data and machine-specific state.

New batch contents live together under:

```text
local/batches/<batchName>/
  raw/
  metadata/
  centers/
  selected_scans/
  results/inphase/
  results/phase/
  results/afm/
```

Copy:

```matlab
local_paths_template.m
```

to:

```matlab
local_paths.m
```

and edit the optional private batch parent if local batches should live
outside this repo.

Copy:

```matlab
active_batch_config_template.m
```

to:

```matlab
active_batch_config.m
```

and choose which batch to run.

The copied `active_batch_config.m` returns a batch config such as
`config_batch_20260521_3()`. The tracked template keeps this setup visible
without committing the active private choice.

AFM runs use a separate selector. Copy:

```matlab
active_afm_batch_config_template.m
```

to:

```matlab
active_afm_batch_config.m
```

and choose which AFM batch config to run (see `docs/AFM_MODULE.md`).

Files such as `local_paths.m`, `active_batch_config.m`,
`active_afm_batch_config.m`, local batch raw data, metadata, centers,
results, selected-scan lists, and logs are ignored by Git.
