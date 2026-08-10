# [Storage Level Output](@id manual-outputs-storage-level)

## Contents

[Overview](@ref "manual-outputs-storage-level-overview") | [Columns](@ref "manual-outputs-storage-level-columns") | [Configuration](@ref "manual-outputs-storage-level-configuration") | [Assumptions](@ref "manual-outputs-storage-level-assumptions") | [Examples](@ref "manual-outputs-storage-level-examples") | [See Also](@ref "manual-outputs-storage-level-see-also")

## [Overview](@id manual-outputs-storage-level-overview)

**File:** `storage_level.csv`

`storage_level.csv` records the state of charge (energy or mass stored) of every storage component in the system at the end of each representative time step. Only assets that contain a `Storage` component (e.g., `Battery`, `GasStorage`, `HydroReservoir`) produce rows in this file.

The storage level represents how much commodity is held inside the storage at a given moment. Tracking this over time reveals charging and discharging patterns, how often storage reaches its capacity limits, and whether inter-period energy carry-over occurs.

!!! note "Representative time steps vs. full year"
    `storage_level.csv` contains only the representative time steps used in the optimization. If time-domain reduction (TDR) is active, this is a subset of the full year. Enable `WriteFullTimeseries = true` in `case_settings.json` to also write full-year storage levels. See [Full Time Series Output](@ref "manual-outputs-full-timeseries").

## [Columns](@id manual-outputs-storage-level-columns)

| Column | Type | Description |
|---|---|---|
| `commodity` | String | Commodity type stored (e.g., `Electricity`, `NaturalGas`, `Hydrogen`) |
| `zone` | String | Zone (location) where the storage asset is installed |
| `resource_id` | String | Unique identifier of the parent asset (e.g., `battery_SE`) |
| `component_id` | String | Unique identifier of the storage component (e.g., `battery_SE_storage`) |
| `resource_type` | String | Asset type of the parent asset (e.g., `Battery`, `GasStorage`, `HydroReservoir`) |
| `component_type` | String | Type of the storage component (e.g., `Storage{Electricity}`, `Storage{NaturalGas}`) |
| `variable` | String | Always `"storage_level"` |
| `time` | Int | Representative time step index (1-based integer, matches `time` in other output files) |
| `value` | Float64 | Amount of commodity currently stored, in the commodity's native units (MWh for electricity, tonnes for mass-based commodities) |

## [Configuration](@id manual-outputs-storage-level-configuration)

| Setting | File | Default | Effect |
|---|---|---|---|
| `OutputLayout` (or `OutputLayout.StorageLevel`) | `macro_settings.json` | `"long"` | Set to `"wide"` to pivot time steps into columns. |
| `WriteFullTimeseries` | `case_settings.json` | `false` | When `true` and TDR is active, also write full-year storage levels to `full_time_series/storage_level.csv`. |

## [Assumptions](@id manual-outputs-storage-level-assumptions)

- **End-of-timestep values.** The `value` at time step `t` is the state of charge at the **end** of that time step, after all flows (charging and discharging) at step `t` have been processed.
- **Units.** Storage level is reported in the native units of the stored commodity. For electricity, this is MWh. For gas or biomass, this is tonnes. Ensure your capacity and rate inputs use consistent units.
- **Cyclic storage constraint.** By default, Macro enforces a cyclic storage constraint within each representative period: the state of charge at the end of the last time step in a representative period must equal the state of charge at the start of the first time step of that period. This is sometimes called the "wrap-around" or "periodic boundary" condition.
- **Long-Duration Storage.** Assets modeled as `LongDurationStorage` relax the within-period cyclic constraint and allow energy carry-over between representative periods. See [Storage](@ref "manual-storage-overview") for details.
- **Capacity limit.** The storage level is bounded above by the `storage_capacity` of the storage component. The level will never exceed the installed storage capacity. 
- **Multi-period models.** In multi-period (planning) models, each `results_period_N/` directory contains storage levels for the representative time steps of period N. Between-period carry-over (for Long-Duration Storage) is handled internally by the model.

## [Examples](@id manual-outputs-storage-level-examples)

### Default Long Format (example rows)

| commodity | zone | resource\_id | component\_id | resource\_type | component\_type | variable | time | value |
|---|---|---|---|---|---|---|---|---|
| Electricity | SE | battery\_SE | battery\_SE\_storage | Battery | Storage{Electricity} | storage\_level | 1 | 0.0 |
| Electricity | SE | battery\_SE | battery\_SE\_storage | Battery | Storage{Electricity} | storage\_level | 2 | 85.3 |
| Electricity | SE | battery\_SE | battery\_SE\_storage | Battery | Storage{Electricity} | storage\_level | 3 | 200.0 |
| Electricity | SE | battery\_SE | battery\_SE\_storage | Battery | Storage{Electricity} | storage\_level | 4 | 112.7 |

### Wide Format (`OutputLayout.StorageLevel = "wide"`)

| commodity | zone | resource\_id | component\_id | resource\_type | component\_type | variable | 1 | 2 | 3 | 4 | … |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Electricity | SE | battery\_SE | battery\_SE\_storage | Battery | Storage{Electricity} | storage\_level | 0.0 | 85.3 | 200.0 | 112.7 | … |

### Reading and Plotting Storage Levels

```julia
using CSV, DataFrames, Plots

storage = CSV.read("results/storage_level.csv", DataFrame)

# Filter to a specific asset
battery_SE = filter(r -> r.resource_id == "battery_SE", storage)

# Plot state of charge over representative time steps
plot(battery_SE.time, battery_SE.value,
     xlabel="Time Step", ylabel="Storage Level (MWh)",
     title="Battery SE State of Charge", legend=false)
```

## [See Also](@id manual-outputs-storage-level-see-also)

- [Outputs Overview](@ref "manual-outputs-overview") — overview of all output files and settings
- [Flows Output](@ref "manual-outputs-flows") — charge and discharge flows associated with storage
- [Full Time Series Output](@ref "manual-outputs-full-timeseries") — 8760-hour expanded storage levels
- [Time Weights Output](@ref "manual-outputs-time-weights") — weights for interpreting representative time steps
- [Storage](@ref "manual-storage-overview") — storage component parameters and types (including Long-Duration Storage)
- [Time Data](@ref "Time Data") — representative periods and cyclic storage constraint
