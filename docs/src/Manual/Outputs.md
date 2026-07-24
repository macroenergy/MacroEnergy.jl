# Outputs

## Contents

[Overview](@ref "manual-outputs-overview") | [Directory Structure](@ref "manual-outputs-directory") | [Settings](@ref "manual-outputs-settings") | [Output Files](@ref "manual-outputs-files") | [MacroEnergy API](@ref "manual-outputs-api") | [See Also](@ref "manual-outputs-see-also")

## [Overview](@id manual-outputs-overview)

After solving a Macro model, results are automatically written to disk by [`write_outputs`](@ref). The output files are CSV-format tabular data that describe the optimal capacity decisions, operational dispatch, and costs of every asset in the system.

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
| `OverwriteResults` | `Bool` | `false` | If `true`, overwrite the output directory on each run. If `false`, append `_001`, `_002`, … suffixes to avoid overwriting. |
| `OutputDir` | `String` | `"results"` | Base name for the results directory. |
| `DualExportsEnabled` | `Bool` | `true` | If `true`, write [`balance_duals.csv`](@ref "manual-outputs-duals-balance") and [`co2_cap_duals.csv`](@ref "manual-outputs-duals-co2"). |

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

### Full Time Series Setting

!!! warn "Full time series output"
    The `WriteFullTimeseries` setting needs to be set in `case_settings.json` (not `macro_settings.json`).

| Setting | File | Default | Description |
|---|---|---|---|
| `WriteFullTimeseries` | `case_settings.json` | `false` | If `true` and time-domain reduction (TDR) is used, write expanded time-series outputs covering all `TotalHoursModeled` hours to a `full_time_series/` subdirectory. |

## [Output Files](@id manual-outputs-files)

The table below lists all output files produced by Macro. Click the file name to go to the detailed page for that output.

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
| [`balance_duals.csv`](@ref "manual-outputs-duals-balance") | Shadow prices of commodity balance constraints (locational marginal prices) | `DualExportsEnabled = true` (default) |
| [`co2_cap_duals.csv`](@ref "manual-outputs-duals-co2") | Shadow prices of CO₂ cap constraints (carbon prices) | `DualExportsEnabled = true` (default) |
| [`<case_name>.log`](@ref "manual-outputs-log-file") | Plain-text log of all messages emitted during the run | `log_to_file = true` (default) |
| [`full_time_series/`](@ref "manual-outputs-full-timeseries") | Expanded time-series outputs covering all `TotalHoursModeled` hours | `WriteFullTimeseries = true` and TDR used |
| [`benders_convergence.csv`](@ref "manual-outputs-benders") | Benders decomposition convergence metrics per iteration | Benders algorithm only |


## [MacroEnergy API](@id manual-outputs-api)

### Writing Outputs

The following functions write output files. They are called automatically by `run_case`/`solve_case` but can also be invoked individually.

| Function | File(s) Written |
|---|---|
| [`write_outputs`](@ref) | All files (orchestrator) |
| [`write_capacity`](@ref) | `capacity.csv` |
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

