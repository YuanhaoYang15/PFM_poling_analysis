# Local Settings

This folder stores machine-specific settings and manually picked centers.

Copy:

```matlab
local_paths_template.m
```

to:

```matlab
local_paths.m
```

and edit the raw data roots.

Copy:

```matlab
active_batch_config_template.m
```

to:

```matlab
active_batch_config.m
```

and choose which batch to run.

Files such as `local_paths.m`, `active_batch_config.m`, and picked-center `.mat` files are ignored by Git.
