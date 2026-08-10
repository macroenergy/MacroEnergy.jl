# [Flows Output](@id manual-outputs-flows)

## Contents

[Overview](@ref "manual-outputs-flows-overview") | [Columns](@ref "manual-outputs-flows-columns") | [Sign Convention](@ref "manual-outputs-flows-sign") | [Configuration](@ref "manual-outputs-flows-configuration") | [Assumptions](@ref "manual-outputs-flows-assumptions") | [Examples](@ref "manual-outputs-flows-examples") | [See Also](@ref "manual-outputs-flows-see-also")

## [Overview](@id manual-outputs-flows-overview)

**File:** `flows.csv`

`flows.csv` records the optimal commodity flow along every edge in the system at every representative time step. It is the primary operational output — it shows how much of each commodity is produced, transported, or consumed by each asset component at each point in time.

The file uses **long format** by default: each row is a single (component, time step) observation. An optional **wide format** pivots time steps into columns.

!!! note "Representative time steps vs. full year"
    `flows.csv` contains only the time steps used in the optimization (the representative periods). If time-domain reduction (TDR) is active, this is a subset of the full year. To obtain full-year (8760-hour) flows, enable `WriteFullTimeseries = true` in `case_settings.json`. See [Full Time Series Output](@ref "manual-outputs-full-timeseries") for details.

## [Columns](@id manual-outputs-flows-columns)

| Column | Type | Description |
|---|---|---|
| `commodity` | String | Commodity type carried by the edge (e.g., `Electricity`, `NaturalGas`, `CO2`) |
| `node_in` | String | Identifier of the vertex at the **start** (origin) of the edge |
| `node_out` | String | Identifier of the vertex at the **end** (destination) of the edge |
| `resource_id` | String | Unique identifier of the parent asset |
| `component_id` | String | Unique identifier of the edge component |
| `resource_type` | String | Asset type of the parent asset (e.g., `ThermalPower{NaturalGas}`, `Battery`, `VRE`) |
| `component_type` | String | Type of the edge (e.g., `UnidirectionalEdge{Electricity}`, `BidirectionalEdge{NaturalGas}`) |
| `variable` | String | Always `"flow"` |
| `time` | Int | Representative time step index (1-based integer, matches `time` in other output files) |
| `value` | Float64 | Flow value at this time step, in commodity units per hour (see [Sign Convention](@ref "manual-outputs-flows-sign")) |

## [Sign Convention (only for unidirectional edges)](@id manual-outputs-flows-sign) 

Flow values can be positive or negative. The sign indicates the direction of flow relative to the edge's defined direction (from `node_in` to `node_out`). The interpretation of the sign depends on the types of the "vertices" (nodes, transformations, storage) connected by the edge. The table below summarizes the sign convention for unidirectional edges:

| `node_in` type | `node_out` type | Sign | Interpretation |
|---|---|---|---|
| `Node` | `Node` | Positive | Commodity moves between two network nodes |
| `Node` | `Transformation` | Negative | Commodity flows into a conversion process (e.g., fuel input to a power plant) |
| `Node` | `Storage` | Negative | Commodity is being charged into storage (leaving the node) |
| `Transformation` | `Node` | Positive | Commodity flows out of a conversion process (e.g., electricity output from a power plant) |
| `Transformation` | `Storage` | Negative | Converted commodity flows into storage |
| `Transformation` | `Transformation` | Positive | Commodity passes between two conversion stages |
| `Storage` | `Node` | Positive | Commodity is being discharged from storage (entering the node) |
| `Storage` | `Storage` | Positive | Commodity moves between two storage components |
| `Storage` | `Transformation` | Positive | Stored commodity flows into a conversion process |

!!! note "Bidirectional edges"
    For bidirectional edges, the flow is determined by the optimization and can be positive or negative. 

!!! note "Interpreting storage flows"
    For a `Battery` asset, the charge edge (grid → storage) will show **negative** values when charging, and the discharge edge (storage → grid) will show **positive** values when discharging.

## [Configuration](@id manual-outputs-flows-configuration)

| Setting | File | Default | Effect |
|---|---|---|---|
| `OutputLayout` (or `OutputLayout.Flow`) | `macro_settings.json` | `"long"` | Set to `"wide"` to pivot time steps into columns (rows become components, columns become time step indices). |
| `WriteFullTimeseries` | `case_settings.json` | `false` | When `true` and TDR is active, also write expanded 8760-hour flows to `full_time_series/flows.csv`. |

## [Assumptions](@id manual-outputs-flows-assumptions)

- **Units.** Flow values are in commodity units per hour. For electricity this is MW (megawatts); for biomass, or other mass-based commodities this is in the mass units used in your inputs (e.g., tonnes/hour). 
- **Annual totals.** To compute the annual total flow for a component, multiply each time step's flow value by its `weight` from `time_weights.csv` and sum. This accounts for how many full-year hours each representative time step represents:
  ```
  Annual flow = Σ_t  value(t) × weight(t) × hours_per_timestep
  ```
- **Time step index.** The `time` column is an integer index (1, 2, 3, …) corresponding to the representative time steps used in the optimization. It matches the `time` column in `storage_level.csv`, `curtailment.csv`, `non_served_demand.csv`, and `time_weights.csv`. It does **not** represent a calendar hour, unless you are using a full-year (8760-hour) time representation without TDR.
- **Filtering.** `write_flow` and `get_optimal_flow` support filtering by `commodity` and `asset_type`. Use these to reduce file size when you only need a subset of results.

## [Examples](@id manual-outputs-flows-examples)

### Default Long Format (example rows)

| commodity | node\_in | node\_out | resource\_id | component\_id | resource\_type | component\_type | variable | time | value |
|---|---|---|---|---|---|---|---|---|---|
| Electricity | elec\_SE | SE\_thermalpower\_transforms | SE\_thermalpower | SE\_thermalpower\_elec\_edge | ThermalPower{NaturalGas} | UnidirectionalEdge{Electricity} | flow | 1 | 450.5 |
| Electricity | elec\_SE | SE\_thermalpower\_transforms | SE\_thermalpower | SE\_thermalpower\_elec\_edge | ThermalPower{NaturalGas} | UnidirectionalEdge{Electricity} | flow | 2 | 380.2 |

### Wide Format (`OutputLayout.Flow = "wide"`)

| commodity | node\_in | node\_out | resource\_id | component\_id | resource\_type | component\_type | variable | 1 | 2 | 3 | … |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Electricity | elec\_SE | SE\_thermalpower\_transforms | SE\_thermalpower | SE\_thermalpower\_elec\_edge | ThermalPower{NaturalGas} | UnidirectionalEdge{Electricity} | flow | 450.5 | 380.2 | … | … |

### Writing and Reading Flows

- [`write_flow`](@ref) allows you to write flow data to a custom file path, with optional filters for commodity, asset type, or component type. This is useful for exporting subsets of the flow data or for writing to a different location.
- [`get_optimal_flow`](@ref) returns the flow data as a DataFrame without writing a file. This is useful for programmatic access to flow values within Julia.

```julia
# Write flows for the full system
write_flow("flows.csv", system)

# Write only electricity flows
write_flow("flows_elec.csv", system, commodity="Electricity")

# Write flows for thermal power only (parameter-free matching)
write_flow("flows_thermal.csv", system, asset_type="ThermalPower")

# Get flows as a DataFrame
df = get_optimal_flow(system)

# Compute annual electricity generation for each component
using DataFrames, CSV
flows = CSV.read("results/flows.csv", DataFrame)
weights = CSV.read("results/time_weights.csv", DataFrame)
elec_flows = flows[flows.commodity .== "Electricity", :]
# join weights and compute annual total
annual = leftjoin(elec_flows, weights, on=:time)
annual.annual_MWh = annual.value .* annual.weight
```

## [See Also](@id manual-outputs-flows-see-also)

- [Outputs Overview](@ref "manual-outputs-overview") — overview of all output files and settings
- [Time Weights Output](@ref "manual-outputs-time-weights") — weights for annualizing flows
- [Full Time Series Output](@ref "manual-outputs-full-timeseries") — 8760-hour expanded flows
- [Storage Level Output](@ref "manual-outputs-storage-level") — storage state of charge (related to charge/discharge flows)
- [Curtailment Output](@ref "manual-outputs-curtailment") — curtailed VRE generation
- [Time Data](@ref "Time Data") — representative periods and the time step index
- [Edges](@ref "manual-edges-overview") — edge types and flow direction conventions
