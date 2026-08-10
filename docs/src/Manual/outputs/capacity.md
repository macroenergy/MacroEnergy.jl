# [Capacity Output](@id manual-outputs-capacity)

## Contents

[Overview](@ref "manual-outputs-capacity-overview") | [Columns](@ref "manual-outputs-capacity-columns") | [Variable Types](@ref "manual-outputs-capacity-variables") | [Configuration](@ref "manual-outputs-capacity-configuration") | [Assumptions](@ref "manual-outputs-capacity-assumptions") | [Examples](@ref "manual-outputs-capacity-examples") | [Cross-Period Summary](@ref "manual-outputs-capacity-summary") | [See Also](@ref "manual-outputs-capacity-see-also")

## [Overview](@id manual-outputs-capacity-overview)

**File:** `capacity.csv`

`capacity.csv` records the capacity of every edge and storage component in the system after the optimization. For each component, five capacity variables are reported: total optimal capacity, new capacity added in this period, capacity retired, capacity retrofitted, and existing (pre-installed) capacity at the start of the period.

This is one of the most important output files. Capacity decisions are the primary investment variables in Macro — the flows and costs all depend on the capacity choices made here.

The file uses **long format** by default: every (component, variable) combination occupies one row. However, to facilitate easier analysis of capacity breakdowns, an optional **wide format** pivots the `variable` column into separate columns for each capacity type (total, new, retired, existing, retrofitted).

## [Columns](@id manual-outputs-capacity-columns)

| Column | Type | Description |
|---|---|---|
| `commodity` | String | Commodity type carried by the component (e.g., `Electricity`, `Biomass_Wood`, `CO2`) |
| `zone` | String | Zone (location) where the component's parent asset is installed |
| `resource_id` | String | Unique identifier of the parent asset (e.g., `SE_battery`) |
| `component_id` | String | Unique identifier of the specific edge or storage component (e.g., `SE_battery_discharge_edge`) |
| `resource_type` | String | Asset type of the parent asset (e.g., `Battery`, `ThermalPower{NaturalGas}`, `VRE`) |
| `component_type` | String | Type of the component (e.g., `UnidirectionalEdge{Electricity}`, `Storage{Electricity}`) |
| `variable` | String | Which capacity metric is reported (see [Variable Types](@ref "manual-outputs-capacity-variables")) |
| `year` | Int | The period's calendar year, only present when `StartYear` is set in `case_settings.json` (see [Configuration](@ref "manual-outputs-capacity-configuration")) |
| `value` | Float64 | Capacity value in the system's power or energy units (default: MW or MWh) |

## [Variable Types](@id manual-outputs-capacity-variables)

The `variable` column takes one of five values, all reported for each component in the same file:

| `variable` | Description |
|---|---|
| `capacity` | Total installed capacity after the optimization: `existing + new − retired` |
| `new_capacity` | Capacity newly added during this planning period |
| `retired_capacity` | Capacity retired (decommissioned) during this planning period |
| `existing_capacity` | Capacity that was pre-installed at the start of this planning period (not a decision variable) |
| `retrofitted_capacity` | Capacity converted to a different technology via retrofitting (only non-zero when `Retrofitting = true`) |

!!! note "Retrofitting"
    `retrofitted_capacity` rows only appear when `Retrofitting = true` in `macro_settings.json`. In all other runs the row is omitted.

## [Configuration](@id manual-outputs-capacity-configuration)

| Setting | File | Default | Effect |
|---|---|---|---|
| `OutputLayout` (or `OutputLayout.Capacity`) | `macro_settings.json` | `"long"` | Set to `"wide"` to pivot the `variable` column into separate columns: `capacity`, `new_capacity`, `retired_capacity`, `existing_capacity` (and `retrofitted_capacity` if applicable). |
| `Retrofitting` | `macro_settings.json` | `false` | When `true`, a `retrofitted_capacity` row is added for each component. |
| `StartYear` | `case_settings.json` | not set | The calendar year of the first period (e.g. `2026`). When set, each period's `year` is `StartYear` plus the sum of `PeriodLengths` of all preceding periods, and this populates the `year` column in `capacity.csv` and the `_<year>` column suffixes in [`capacity_summary.csv`](@ref "manual-outputs-capacity-summary"). When not set, `year` is omitted from `capacity.csv` entirely, and `capacity_summary.csv` falls back to labeling periods by their 1-based index instead. |

## [Assumptions](@id manual-outputs-capacity-assumptions)

- **Units** follow whatever unit system you define in your inputs. The default assumption in the Macro documentation is MW for power capacity and MWh for energy storage capacity. Capacity is reported per component (edge or storage), not per asset. A single asset may contain multiple components with separate capacity rows.
- **Components without capacity** — components with `has_capacity = false` are excluded from the output. Only components where `has_capacity = true` appear in `capacity.csv`. All storage components are always included (all storages have capacity variables by definition).
- **Multi-period models** — each period's `results_period_N/` directory contains capacity values reflecting the capacity available **during** that planning period. Per the [multi-period accounting assumptions](@ref "manual-multi-period-accounting-general-assumptions"), new capacity comes online at the **beginning** of a period. `existing_capacity` reflects the carry-over from the previous period, and `new_capacity` reflects investments made during period N.
- **Single-period models** — `existing_capacity` is the user-specified `existing_capacity` from the input data. `capacity = existing_capacity + new_capacity - retired_capacity`.
- **Capacity is reported per component, not per asset.** An asset such as a `Battery` will produce rows for each of its edges (charge, discharge) and its storage component separately. Especially for symmetric battery systems, users interested in the total installed battery capacity should typically look at the storage component or the discharge edge.

## [Examples](@id manual-outputs-capacity-examples)

### Default Long Format

| commodity | zone | resource\_id | component\_id | resource\_type | component\_type | variable | value |
|---|---|---|---|---|---|---|---|
| Electricity | SE | battery\_SE | battery\_SE\_storage | Battery | Storage{Electricity} | capacity | 200.0 |
| Electricity | SE | battery\_SE | battery\_SE\_storage | Battery | Storage{Electricity} | new\_capacity | 200.0 |
| Electricity | SE | battery\_SE | battery\_SE\_storage | Battery | Storage{Electricity} | retired\_capacity | 0.0 |
| Electricity | SE | battery\_SE | battery\_SE\_storage | Battery | Storage{Electricity} | existing\_capacity | 0.0 |

### Wide Format (`OutputLayout.Capacity = "wide"`)

| commodity | zone | resource\_id | component\_id | resource\_type | component\_type | capacity | new\_capacity | retired\_capacity | existing\_capacity |
|---|---|---|---|---|---|---|---|---|---|
| Electricity | SE | battery\_SE | battery\_SE\_storage | Battery | Storage{Electricity} | 200.0 | 200.0 | 0.0 | 0.0 |

### Writing Capacity Programmatically

- [`write_capacity`](@ref) allows you to write capacity data to a custom file path, with optional filters for commodity, asset type, or component type. This is useful for exporting subsets of the capacity data or for writing to a different location.
- [`get_optimal_capacity`](@ref) returns the capacity data as a DataFrame without writing a file. This is useful for programmatic access to capacity values within Julia.

```julia
# After solving:
(case, model) = solve_case(case_path, optimizer)

# Export capacity for a specific period/system
system = case.systems[1];
write_capacity("my_capacity.csv", system)

# Export only electricity capacity
write_capacity("elec_capacity.csv", system, commodity="Electricity")

# Export only Battery and VRE assets
write_capacity("storage_vre.csv", system, asset_type=["Battery", "VRE"])

# Get capacity as a DataFrame (no file written)
df = get_optimal_capacity(system)
```

## [Cross-Period Summary](@id manual-outputs-capacity-summary)

**File:** `capacity_summary.csv`

For multi-period cases, [`write_capacity_summary`](@ref) combines every period's capacity results into a single file, written once at the top level of the results directory (see [Output Directory Structure](@ref "manual-outputs-directory")) rather than inside any individual `results_period_N/` folder. It is not written for single-period cases.

Each period is labeled either by its calendar `year` (if `StartYear` is set in `case_settings.json`) or by its 1-based period index (if not) — see the `StartYear` row in [Configuration](@ref "manual-outputs-capacity-configuration"). `:existing_capacity` is only included for the first (earliest) period, since for every later period it is always equal to the previous period's final `capacity` and so is redundant.

Like `capacity.csv`, the summary supports both long and wide layouts, controlled independently via `OutputLayout.CapacitySummary`.

### Long Format (default)

Identical schema to `capacity.csv`, stacked across every period, with the period label column (`year` or `period`) placed right before `value`:

| commodity | zone | resource\_id | component\_id | resource\_type | component\_type | variable | year | value |
|---|---|---|---|---|---|---|---|---|
| Electricity | SE | battery\_SE | battery\_SE\_storage | Battery | Storage{Electricity} | existing\_capacity | 2026 | 0.0 |
| Electricity | SE | battery\_SE | battery\_SE\_storage | Battery | Storage{Electricity} | capacity | 2026 | 200.0 |
| Electricity | SE | battery\_SE | battery\_SE\_storage | Battery | Storage{Electricity} | capacity | 2036 | 250.0 |

### Wide Format (`OutputLayout.CapacitySummary = "wide"`)

One row per component; columns are `<variable>_<year>` (or `<variable>_<period>`) for every variable/period combination actually present, in chronological order:

| commodity | zone | resource\_id | component\_id | resource\_type | component\_type | existing\_capacity\_2026 | new\_capacity\_2026 | retired\_capacity\_2026 | capacity\_2026 | new\_capacity\_2036 | retired\_capacity\_2036 | capacity\_2036 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Electricity | SE | battery\_SE | battery\_SE\_storage | Battery | Storage{Electricity} | 0.0 | 200.0 | 0.0 | 200.0 | 50.0 | 0.0 | 250.0 |

A component that doesn't exist yet in the first period (e.g. a technology only built in a later period) gets `0.0` for its earlier-period columns rather than being omitted.

### Writing the Summary Programmatically

[`write_capacity_summary`](@ref) can also be called directly, given a chronologically-ordered vector of per-period `DataFrame`s (as returned by [`write_capacity`](@ref)) and a layout (`"long"` or `"wide"`):

```julia
(case, model) = solve_case(case_path, optimizer)

period_results = [write_capacity(joinpath("period_$i.csv"), system, 1.0) for (i, system) in enumerate(case.systems)]
write_capacity_summary(output_dir, period_results, "wide")
```

## [See Also](@id manual-outputs-capacity-see-also)

- [Outputs Overview](@ref "manual-outputs-overview") — overview of all output files and settings
- [Costs Output](@ref "manual-outputs-costs") — investment and O&M costs associated with capacity decisions
- [Financial Assumptions](@ref "Investment costs") — how investment costs are annualized from CAPEX
- [Multi-Period Accounting](@ref "manual-multi-period-accounting-general-assumptions") — how capacity evolves across planning periods
- [Edges](@ref "manual-edges-overview") — edge investment parameters (`can_expand`, `existing_capacity`, etc.)
- [Storage](@ref "manual-storage-overview") — storage investment parameters
