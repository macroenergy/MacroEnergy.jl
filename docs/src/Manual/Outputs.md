# Outputs

## Contents

[Overview](@ref "manual-outputs-overview") | [Directory Structure](@ref "manual-outputs-directory") | [Settings](@ref "manual-outputs-settings") | [Output Files](@ref "manual-outputs-files") | [Reading All Periods](@ref "manual-outputs-reading-periods") | [MacroEnergy API](@ref "manual-outputs-api") | [See Also](@ref "manual-outputs-see-also")

## [Overview](@id manual-outputs-overview)

After solving a Macro model, results are automatically written to disk by [`write_outputs`](@ref). The output files are tabular data that describe the optimal capacity decisions, operational dispatch, and costs of every asset in the system. They are written as CSV by default; gzip-compressed CSV and Parquet are available through the [`OutputFormat`](@ref "manual-outputs-format") setting, which makes results folders much smaller (see the measured example there).

Outputs are organized into one results directory per modeled period. Within each directory, each output type is stored in its own file. The files use a consistent **long format** by default (one row per observation, with metadata columns identifying the asset and time step), which makes them easy to filter and join using standard data tools. A **wide format** is also available via the [`OutputLayout`](@ref "manual-outputs-settings") setting, which allows pivoting of time steps or variables into columns for easier human readability.

All write functions are called automatically when you run [`run_case`](@ref) (or `solve_case` when using Myopic as solution algorithm). You can also call each function individually to re-export a specific output after modifying a solved system.

## [Output Directory Structure](@id manual-outputs-directory)

### Single-Period Models

For a single-period model, results are written inside a two-level directory structure. An **outer directory** is created from the `OutputDir` setting (default `results` with a numeric suffix), and an **inner `results/` directory** is created inside it for the actual output files:

```
my_case/
├── case_settings.json
├── settings/
│   └── macro_settings.json
├── system/
│   └── ...
├── results_001/              ← outer directory (non-overwrite default)
│   ├── settings.json         ← case-level settings snapshot
|   ├── my_case.log           ← copied here after the run
│   └── results/              ← all output files written here
│       ├── capacity.csv
│       ├── costs.csv
│       ├── flows.csv
│       └── ...
```

When `OverwriteResults = true`, the outer directory name is exactly `OutputDir` (default `results`) with no suffix:

```
my_case/
├── results/                  ← outer directory (overwrite mode)
│   ├── settings.json
│   ├── my_case.log
│   └── results/              ← output files
│       ├── capacity.csv
│       └── ...
```

### Multi-Period Models

For multi-period (planning) models, the same outer directory is created, and each planning period gets its own `results_period_N/` subdirectory inside it. A single `capacity_summary.csv` combining all periods is also written directly inside the outer directory (see [Capacity Output](@ref "manual-outputs-capacity")):

```
my_case/
├── case_settings.json
├── my_case.log               ← written here during the run
└── results_001/                  ← outer directory
    ├── settings.json             ← case-level settings snapshot
    ├── my_case.log               ← copied here after the run
    ├── capacity_summary.csv      ← cross-period capacity summary
    ├── results_period_1/         ← period 1 outputs
    │   ├── capacity.csv
    │   └── ...
    └── results_period_2/         ← period 2 outputs
        ├── capacity.csv
        └── ...
```

### Overwrite Behavior

By default (`OverwriteResults = false`), Macro will not overwrite an existing outer results directory. Instead, it appends an incremental numeric suffix: `results_001`, `results_002`, etc. This is controlled by the `OverwriteResults` and `OutputDir` settings in `macro_settings.json`.

!!! note "Settings snapshot"
    A `settings.json` file is always written inside the outer directory (e.g., `results_001/settings.json`) recording the `case_settings` and `system_settings` used for the run. See [Settings Output](@ref "manual-outputs-settings-output") for details.

## [Output Settings](@id manual-outputs-settings)

The following settings in `macro_settings.json` control the behavior of the output files.

### Layout and Format

| Setting | Type | Default | Description |
|---|---|---|---|
| `OutputLayout` | `String` or `JSON Object` | `"long"` | Output layout for tabular files. `"long"` stacks all observations as rows; `"wide"` pivots time steps or variables to columns. Can be set globally with a single string, or per-file as a JSON object (see below). |
| `OutputFormat` | `String` or `JSON Object` | `"csv"` | File format for tabular files: `"csv"`, `"csv.gz"` (gzip-compressed CSV) or `"parquet"` (zstd-compressed). Sets the file extension. Can be set globally with a single string, or per output as a JSON object. See [Output Format and Size](@ref "manual-outputs-format"). |
| `WriteOutputs` | `JSON Object` | `{}` | Output files to skip, e.g. `{"Curtailment": false}`. Outputs that are not listed are written. See [Selecting Outputs](@ref "manual-outputs-selecting"). |
| `OutputSignificantDigits` | `Integer` or `null` | `null` | If set, round time-series outputs (flows, storage levels, curtailment, non-served demand and balance duals) to this many significant digits before writing. `null` writes full precision. Capacity, cost and CAPEX files are never rounded. |
| `OverwriteResults` | `Bool` | `false` | If `true`, overwrite the output directory on each run. If `false`, append `_001`, `_002`, … suffixes to avoid overwriting. |
| `OutputDir` | `String` | `"results"` | Base name for the results directory. |
| `OutputAssetTags` | `Bool` | `true` | If `true`, include pipe-separated asset tags in `capacity.csv`, `capacity_summary.csv`, and `capex.csv`. |
| `DualExportsEnabled` | `Bool` | — | **Deprecated**: use `"WriteOutputs": {"Duals": false}` to skip [`balance_duals.csv`](@ref "manual-outputs-duals-balance") and [`co2_cap_duals.csv`](@ref "manual-outputs-duals-co2"). Still accepted with a deprecation warning, and translated to `WriteOutputs.Duals`. For scripts that read it, `system.settings.DualExportsEnabled` is still `true` or `false`, mirroring `WriteOutputs.Duals`. |

### Per-File Layout Control

Instead of a single string, `OutputLayout` can be a JSON object to control layout independently for each output type:

```json
"OutputLayout": {
    "Capacity":        "wide",
    "CapacitySummary": "wide",
    "Costs":           "long",
    "Flow":            "long",
    "StorageLevel":    "long",
    "Curtailment":     "long",
    "NonServedDemand": "long"
}
```

Supported keys: `Capacity`, `CapacitySummary`, `Costs`, `Flow`, `StorageLevel`, `Curtailment`, `NonServedDemand`.

### [Output Format and Size](@id manual-outputs-format)

Time-series outputs make up most of a results folder, and `flows.csv` usually dominates. In long layout, each row repeats the same labels (commodity, nodes, asset, component, type), so the files compress very well. `OutputFormat` writes them compressed:

| Format | Extension | Notes |
|---|---|---|
| `"csv"` (default) | `.csv` | Plain text; opens in any spreadsheet. |
| `"csv.gz"` | `.csv.gz` | Gzip-compressed CSV. Read directly by `CSV.read`, pandas, polars and DuckDB. |
| `"parquet"` | `.parquet` | Columnar and zstd-compressed, with column types stored in the file. The smallest and fastest to load. Read with DuckDB, polars, pandas (with pyarrow) or `Parquet2.jl`. |

For example, here is one multi-period case: 8 periods, 5 zones, 288 time steps per period, long layout. The numbers are the total size of all tables written for the case.

| Setting | Total size | Smaller by |
|---|---|---|
| `"OutputFormat": "csv"` | 184.3 MB | — |
| `"OutputFormat": "csv.gz"` | 12.4 MB | 15× |
| `"OutputFormat": "parquet"` | 7.0 MB | 26× |
| `"OutputFormat": "parquet"`, `"OutputSignificantDigits": 6` | 5.4 MB | 34× |

Ratios depend on the case. Rounding with `OutputSignificantDigits` helps because digits beyond the solver's tolerance are noise that does not compress.

Like `OutputLayout`, `OutputFormat` can be a JSON object to set the format per output. For example, you can keep small tables as plain CSV for spreadsheets and compress the time series:

```json
"OutputFormat": {
    "Flow":            "parquet",
    "StorageLevel":    "parquet",
    "Curtailment":     "parquet",
    "NonServedDemand": "parquet",
    "Duals":           "parquet"
}
```

Supported keys: `Capacity`, `CapacitySummary`, `Capex`, `Costs`, `Curtailment`, `Duals`, `Flow`, `NonServedDemand`, `StorageLevel`, `TimeWeights`. Outputs that are not listed are written as `"csv"`. The `objective_value.csv`, `benders_convergence.csv` and `settings.json` files are always written as CSV/JSON.

!!! note "Full time series"
    Full time series files follow `OutputFormat` too, except that long-layout CSV files are always gzip-compressed (`.csv.gz`). See [Full Time Series](@ref "manual-outputs-full-timeseries").

### [Selecting Outputs](@id manual-outputs-selecting)

`WriteOutputs` switches off individual output files. Outputs that are not listed are written:

```json
"WriteOutputs": {
    "Curtailment":  false,
    "StorageLevel": false
}
```

Supported keys are the same as for `OutputFormat`. `Duals` covers `balance_duals` and `co2_cap_duals`. Switching it off also skips the extra solve that Macro runs to compute duals when the model has integer variables. Switching off an output also skips its file in `full_time_series/`. `Costs` covers all six cost files (discounted and undiscounted, totals and breakdowns by type and zone).

Each period of a multi-period case loads its own `macro_settings.json` (the `settings` entry of each system in `system_data.json`). To get a time series only for some periods (for example, hourly flows only for the final period), point those periods to a settings file that enables it, and point the other periods to one that switches it off. The cross-period `capacity_summary` uses the first period's settings.

!!! warning "Myopic restarts need capacity outputs"
    A Myopic restart reads `capacity.csv` (or `capacity.csv.gz`/`capacity.parquet`) from each earlier period of the restart folder. Keep `Capacity` enabled if you may want to restart a run.

    With `OverwriteResults = true`, files from an earlier run stay in the folder. If you change `OutputFormat` between runs into the same folder, a period can end up with two capacity files (e.g., `capacity.csv` and `capacity.parquet`). A restart then stops with an error rather than guess which one is current; delete the stale file.

    A Myopic run that stops early (`StopAfterPeriod` before the last period) is meant to be continued, so it fails before the first solve if `Capacity` is switched off for any period it writes. A run to the last period only logs a warning.

### Full Time Series Setting

!!! warn "Full time series output"
    The `WriteFullTimeseries` setting needs to be set in `case_settings.json` (not `macro_settings.json`).

| Setting | File | Default | Description |
|---|---|---|---|
| `WriteFullTimeseries` | `case_settings.json` | `false` | If `true` and time-domain reduction (TDR) is used, write expanded time-series outputs covering all `TotalHoursModeled` hours to a `full_time_series/` subdirectory. |

## [Output Files](@id manual-outputs-files)

The table below lists all output files produced by Macro. Click the file name to go to the detailed page for that output.

File names are shown with the default `.csv` extension. With [`OutputFormat`](@ref "manual-outputs-format"), tabular files end in `.csv.gz` or `.parquet` instead, and files switched off in [`WriteOutputs`](@ref "manual-outputs-selecting") are not written.

!!! note "Written when column"
    The **Written when** column indicates whether the file is always produced or only under specific conditions. There are three types of conditions:
    - **Always** — written on every successful run.
    - **System content** — written only when the system contains the relevant asset type or constraint (e.g., no curtailment file if there are no VRE assets).
    - **Setting / algorithm** — written only when a particular setting is enabled or a specific solution algorithm is used.

| File | Description | Written when |
|---|---|---|
| [`capacity.csv`](@ref "manual-outputs-capacity") | Optimal, new, retired, retrofitted, and existing capacity for every asset component | Always |
| [`capacity_summary.csv`](@ref "manual-outputs-capacity-summary") | All periods' `capacity.csv` combined into a single cross-period file | Multi-period case |
| [`costs.csv`](@ref "manual-outputs-costs-system") | Total discounted system costs (fixed, variable, total) | Always |
| [`undiscounted_costs.csv`](@ref "manual-outputs-costs-system") | Total undiscounted system costs | Always |
| [`costs_by_type.csv`](@ref "manual-outputs-costs-breakdown") | Discounted cost breakdown by asset type and cost category | Always |
| [`costs_by_zone.csv`](@ref "manual-outputs-costs-breakdown-zone") | Discounted cost breakdown by zone and cost category | Always |
| [`undiscounted_costs_by_type.csv`](@ref "manual-outputs-costs-breakdown") | Undiscounted cost breakdown by asset type and cost category | Always |
| [`undiscounted_costs_by_zone.csv`](@ref "manual-outputs-costs-breakdown-zone") | Undiscounted cost breakdown by zone and cost category | Always |
| [`flows.csv`](@ref "manual-outputs-flows") | Commodity flow for every edge at every representative time step | Always |
| [`time_weights.csv`](@ref "manual-outputs-time-weights") | Representative period weights mapping each time step to its full-year equivalent hours | Always |
| [`settings.json`](@ref "manual-outputs-settings-output") | Snapshot of all case and system settings used for the run | Always |
| [`storage_level.csv`](@ref "manual-outputs-storage-level") | State of charge for every storage component at every representative time step | System has storage assets |
| [`curtailment.csv`](@ref "manual-outputs-curtailment") | Curtailed generation for VRE assets at every representative time step | System has VRE assets with `has_capacity = true` |
| [`non_served_demand.csv`](@ref "manual-outputs-nsd") | Non-served demand for every node with NSD variables at every representative time step | System has nodes with NSD variables |
| [`balance_duals.csv`](@ref "manual-outputs-duals-balance") | Shadow prices of commodity balance constraints (locational marginal prices) | `WriteOutputs.Duals = true` (default) |
| [`co2_cap_duals.csv`](@ref "manual-outputs-duals-co2") | Shadow prices of CO₂ cap constraints (carbon prices) | `WriteOutputs.Duals = true` (default) |
| [`<case_name>.log`](@ref "manual-outputs-log-file") | Plain-text log of all messages emitted during the run | `log_to_file = true` (default) |
| [`full_time_series/`](@ref "manual-outputs-full-timeseries") | Expanded time-series outputs covering all `TotalHoursModeled` hours | `WriteFullTimeseries = true` and TDR used |
| [`benders_convergence.csv`](@ref "manual-outputs-benders") | Benders decomposition convergence metrics per iteration | Benders algorithm only |

## [Reading All Periods as One Table](@id manual-outputs-reading-periods)

Each period's results are in their own `results_period_N/` folder. To analyze all periods together, read the per-period files as one table with a glob pattern. The examples below read Parquet flows. They work the same way for `.csv` and `.csv.gz` files (use `read_csv` in DuckDB, `pl.scan_csv` in polars).

With [DuckDB](https://duckdb.org) (SQL, Python, R or Julia). `filename = true` adds a column with each row's source file, from which the period can be extracted:

```sql
SELECT regexp_extract(filename, 'results_period_(\d+)', 1)::INT AS period, *
FROM read_parquet('results_001/results_period_*/flows.parquet', filename = true);
```

The same query from Julia, using the DuckDB.jl package:

```julia
using DuckDB, DataFrames
db = DBInterface.connect(DuckDB.DB)
flows = DataFrame(DBInterface.execute(db, """
    SELECT regexp_extract(filename, 'results_period_(\\d+)', 1)::INT AS period, *
    FROM read_parquet('results_001/results_period_*/flows.parquet', filename = true)
"""))
```

With polars (Python):

```python
import polars as pl
flows = pl.scan_parquet("results_001/results_period_*/flows.parquet", include_file_paths="file").collect()
```

With pandas (Python, requires pyarrow):

```python
import glob, re
import pandas as pd
flows = pd.concat(
    pd.read_parquet(f).assign(period=int(re.search(r"results_period_(\d+)", f).group(1)))
    for f in sorted(glob.glob("results_001/results_period_*/flows.parquet"))
)
```

DuckDB and polars only read the columns and rows a query needs, so filtering or aggregating across all periods does not load every file into memory.

## [MacroEnergy API](@id manual-outputs-api)

### Writing Outputs

The following functions write output files. They are called automatically by `run_case`/`solve_case` but can also be invoked individually.

| Function | File(s) Written |
|---|---|
| [`write_outputs`](@ref) | All files (orchestrator) |
| [`write_capacity`](@ref) | `capacity.csv` |
| [`write_capex`](@ref) | `capex.csv` |
| [`write_capacity_summary`](@ref) | `capacity_summary.csv` (multi-period only) |
| [`write_costs`](@ref) | `costs.csv` |
| [`write_undiscounted_costs`](@ref) | `undiscounted_costs.csv` |
| [`write_flow`](@ref) | `flows.csv` |
| [`write_storage_level`](@ref) | `storage_level.csv` |
| [`write_curtailment`](@ref) | `curtailment.csv` |
| [`write_non_served_demand`](@ref) | `non_served_demand.csv` |
| [`write_duals`](@ref) | `balance_duals.csv`, `co2_cap_duals.csv` |
| [`write_full_timeseries`](@ref) | `full_time_series/` |
| [`write_time_weights`](@ref) | `time_weights.csv` |

### Extracting Results as DataFrames

The following functions return output data as Julia `DataFrame` objects without writing to disk. They are useful for post-processing within a Julia session.

| Function | Returns |
|---|---|
| [`get_optimal_capacity`](@ref) | Optimal total capacity per component |
| [`get_capex`](@ref) | Upfront CAPEX per capacity component |
| [`get_optimal_flow`](@ref) | Optimal flow per edge per time step |
| [`get_optimal_storage_level`](@ref) | Optimal storage state of charge per time step |
| [`get_optimal_curtailment`](@ref) | Curtailment per VRE edge per time step |
| [`get_optimal_non_served_demand`](@ref) | Non-served demand per node per time step |

### Filtering Results

[`write_capacity`](@ref) and [`write_flow`](@ref) (and their corresponding `get_optimal_*` functions) accept optional filters:

- **`commodity`**: filter to one or more commodity types (e.g., `commodity="Electricity"`)
- **`asset_type`**: filter to one or more asset types (e.g., `asset_type="ThermalPower"`)

Two pattern-matching modes are supported:

1. **Parameter-free matching** — `"ThermalPower"` matches `ThermalPower{NaturalGas}`, `ThermalPower{Uranium}`, etc.
2. **Wildcard matching** — `"ThermalPower*"` additionally matches `ThermalPowerCCS{NaturalGas}`, etc.

```julia
# Write only electricity flows for thermal power plants
write_flow("flows_elec_thermal.csv", system, commodity="Electricity", asset_type="ThermalPower")
```

## [See Also](@id manual-outputs-see-also)

- [Time Data](@ref "Time Data") — explanation of representative periods, subperiod weights, and TDR
- [Financial Assumptions](@ref "Investment costs") — how investment costs are annualized
- [Multi-Period Accounting](@ref "manual-multi-period-accounting-general-assumptions") — discounting and cost accounting across periods
- [Writing Results (User Guide)](@ref "user-write-results") — step-by-step guide to customizing output
- [Writing Output Data (Reference)](@ref "reference-output-functions") — full API reference for all write functions
