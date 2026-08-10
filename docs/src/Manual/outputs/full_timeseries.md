# [Full Time Series Output](@id manual-outputs-full-timeseries)

## Contents

[Overview](@ref "manual-outputs-full-timeseries-overview") | [Files Produced](@ref "manual-outputs-full-timeseries-files") | [Reconstruction Method](@ref "manual-outputs-full-timeseries-reconstruction") | [Configuration](@ref "manual-outputs-full-timeseries-configuration") | [Assumptions](@ref "manual-outputs-full-timeseries-assumptions") | [Examples](@ref "manual-outputs-full-timeseries-examples") | [See Also](@ref "manual-outputs-full-timeseries-see-also")

## [Overview](@id manual-outputs-full-timeseries-overview)

**Directory:** `full_time_series/` (inside the results directory)

**Condition:** Only written when `WriteFullTimeseries = true` in `case_settings.json` **and** the system uses time-domain reduction (TDR).

When time-domain reduction (TDR) is used, the optimization runs over a small set of representative periods (e.g., 3 representative weeks) rather than the full year (8,760 hours). The `full_time_series/` subdirectory contains the standard operational outputs **expanded back to all `TotalHoursModeled` hours** using the period map. This makes it easier to compute annual statistics, produce time series plots, or compare model outputs against historical data — without having to manually apply subperiod weights.

If TDR is not used (i.e., the model already runs over the full year), `WriteFullTimeseries` has no effect and the subdirectory is not created.

!!! tip "File sizes"
    Full time series files can be very large (up to 8,760 rows × many components). Long-format files are automatically written in **compressed `.csv.gz` format** to manage file sizes. Wide-format files use standard `.csv`.

## [Files Produced](@id manual-outputs-full-timeseries-files)

The following files are written inside `full_time_series/`:

| File | Format | Condition | Description |
|---|---|---|---|
| `flows.csv` or `flows.csv.gz` | Wide / Long (`.gz`) | Always (if enabled) | Expanded commodity flows for all edges |
| `non_served_demand.csv` or `non_served_demand.csv.gz` | Wide / Long (`.gz`) | Always (if enabled) | Expanded non-served demand for all NSD-enabled nodes |
| `storage_level.csv` or `storage_level.csv.gz` | Wide / Long (`.gz`) | Always (if enabled) | Expanded storage state of charge |
| `curtailment.csv` or `curtailment.csv.gz` | Wide / Long (`.gz`) | Always (if enabled) | Expanded VRE curtailment |
| `balance_duals.csv` | Wide | `DualExportsEnabled = true` | Expanded locational marginal prices |

The file format (`.csv` vs `.csv.gz`) is determined automatically based on the `OutputLayout` setting:
- **Long format** → compressed `.csv.gz`
- **Wide format** → standard `.csv`

The column structure of each file is identical to the corresponding file in the parent results directory (e.g., `flows.csv` in `full_time_series/` has the same columns as `flows.csv` in `results/`), except that the `time` column now runs from `1` to `TotalHoursModeled` instead of only the representative time steps.

## [Reconstruction Method](@id manual-outputs-full-timeseries-reconstruction)

Full time series are reconstructed from representative-period results using the **period map** (`SubPeriodMap`) specified in the `time_data.json` input file.

The reconstruction proceeds as follows:

1. For each full-year sub-period, look up which representative sub-period it was assigned to (via the period map).
2. Copy the values for that representative sub-period's time steps into the corresponding positions for the full-year sub-period.
3. Repeat for all full-year sub-periods.

```math
\text{full\_ts}[\text{full\_period\_hours}] = \text{rep\_ts}[\text{representative\_hours}]
```

**Padding for incomplete period maps.** If the period map covers fewer hours than `TotalHoursModeled` (e.g., 52 × 168 = 8,736 < 8,760), the remaining hours are filled by repeating the values of the representative sub-period corresponding to the last calendar sub-period in the map. A warning is logged when padding occurs.

## [Configuration](@id manual-outputs-full-timeseries-configuration)

| Setting | File | Default | Effect |
|---|---|---|---|
| `WriteFullTimeseries` | `case_settings.json` | `false` | Set to `true` to enable writing of the `full_time_series/` subdirectory. Has no effect if TDR is not used. |
| `OutputLayout` (or per-variable keys) | `macro_settings.json` | `"long"` | Controls whether files are written in long (`.csv.gz`) or wide (`.csv`) format. |
| `DualExportsEnabled` | `macro_settings.json` | `true` | When `true`, also writes `full_time_series/balance_duals.csv`. |

## [Assumptions](@id manual-outputs-full-timeseries-assumptions)

- **Only for TDR runs.** If the system does not use TDR (i.e., no period map is provided), `WriteFullTimeseries = true` has no effect and a warning is logged. The full year is already represented in the standard outputs.
- **Storage levels.** The cyclic-within-period constraint means the storage level at the end of a representative sub-period equals the level at its start. This is faithfully reproduced in the expanded storage level: the same state-of-charge profile repeats for all full-year sub-periods assigned to the same representative sub-period. 
- **Large files.** At 8,760 rows × hundreds or thousands of components, long-format files can exceed hundreds of MB. The automatic `.csv.gz` compression typically reduces file sizes by 90%. 
- **Period map required.** The period map (`SubPeriodMap`) must be specified in `time_data.json`. See [Time Data](@ref "Time Data") for how to configure TDR and the period map.

## [Examples](@id manual-outputs-full-timeseries-examples)

### Enabling Full Time Series Output

In `case_settings.json`:

```json
{
    "SolutionAlgorithm": "Monolithic",
    "WriteFullTimeseries": true
}
```

### Reading Full Time Series in Julia

```julia
using CSV, DataFrames

# Read long-format flows
flows_full = CSV.read("results/full_time_series/flows.csv.gz", DataFrame)
# flows_full has 8760 × n_components rows (one per (component, hour) pair)

# Annual electricity generation per component
elec = filter(r -> r.commodity == "Electricity", flows_full)
annual_gen = combine(groupby(elec, :resource_id), :value => sum => :annual_MWh)
```

### Directory Structure After Full Time Series Export

```
results/
├── capacity.csv
├── costs.csv
├── flows.csv
├── storage_level.csv
├── curtailment.csv
├── non_served_demand.csv
├── balance_duals.csv
├── co2_cap_duals.csv
├── time_weights.csv
└── full_time_series/
    ├── flows.csv.gz           ← 8760-hour flows (compressed long format)
    ├── storage_level.csv.gz
    ├── curtailment.csv.gz
    ├── non_served_demand.csv.gz
    └── balance_duals.csv      ← wide format, uncompressed
```

## [See Also](@id manual-outputs-full-timeseries-see-also)

- [Outputs Overview](@ref "manual-outputs-overview") — overview of all output files and settings
- [Time Weights Output](@ref "manual-outputs-time-weights") — the alternative to full time series: use weights to annualize representative-period results
- [Flows Output](@ref "manual-outputs-flows") — the representative-period flows that are expanded
- [Storage Level Output](@ref "manual-outputs-storage-level") — the representative-period storage levels that are expanded
- [Time Data](@ref "Time Data") — period map, TDR configuration, and `reconstruct_timeseries`
