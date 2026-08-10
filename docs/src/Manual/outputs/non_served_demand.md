# [Non-Served Demand Output](@id manual-outputs-nsd)

## Contents

[Overview](@ref "manual-outputs-nsd-overview") | [Columns](@ref "manual-outputs-nsd-columns") | [Segments](@ref "manual-outputs-nsd-segments") | [Configuration](@ref "manual-outputs-nsd-configuration") | [Assumptions](@ref "manual-outputs-nsd-assumptions") | [Examples](@ref "manual-outputs-nsd-examples") | [See Also](@ref "manual-outputs-nsd-see-also")

## [Overview](@id manual-outputs-nsd-overview)

**File:** `non_served_demand.csv`

`non_served_demand.csv` records unmet demand at every node that has non-served demand (NSD) variables enabled, across all representative time steps. Non-served demand represents the portion of demand that the optimizer chose not to meet — this happens when meeting demand would be more expensive than paying the NSD penalty price.

Non-served demand is a demand-side flexibility tool. It prevents the model from becoming infeasible when supply is insufficient, at the cost of a penalty in the objective function. The penalty price is specified in the node's input data.

Only nodes with `max_nsd != [0.0]` (i.e., nodes with non-zero maximum non-served demand) in their input configuration produce rows in this file. If no nodes have NSD variables, the file will not be written.

!!! note "NSD as a soft constraint"
    Non-served demand effectively turns the demand balance constraint into a **soft constraint**. The optimizer will serve demand as long as the marginal cost of doing so is below the NSD penalty price. High NSD values in the results may indicate that supply infrastructure is insufficient, or that the NSD penalty price is too low.

## [Columns](@id manual-outputs-nsd-columns)

| Column | Type | Description |
|---|---|---|
| `commodity` | String | Commodity type at the node (e.g., `Electricity`, `Hydrogen`) |
| `zone` | String | Zone (location) where the node is located |
| `component_id` | String | Unique identifier of the node (e.g., `elec_SE`, `h2_MIDAT`) |
| `component_type` | String | Type of the node (e.g., `Node{Electricity}`) |
| `variable` | String | Always `"non_served_demand"` |
| `segment` | Int | NSD segment index (1-based; see [Segments](@ref "manual-outputs-nsd-segments")) |
| `time` | Int | Representative time step index (1-based integer, matches `time` in other output files) |
| `value` | Float64 | Amount of unmet demand at this node, segment, and time step (same units as demand input) |

## [Segments](@id manual-outputs-nsd-segments)

Non-served demand is modeled using **piecewise-linear segments** that allow different quantities of demand to be unmet at different penalty prices. This mirrors the concept of a "value of lost load" that varies with the amount of load shed:

- **Segment 1** — first block of NSD, up to the limit `max_nsd[1]`, penalized at `nsd_cost[1]`
- **Segment 2** — second block (if defined), up to `max_nsd[2]`, penalized at `nsd_cost[2]`
- etc.

In many models a single segment is used (i.e., all unmet demand is penalized at the same price). In that case, only `segment = 1` rows appear for each node.

The penalty costs for NSD segments are specified in the node's input data under the `nsd_cost` field. These costs appear in `costs.csv` under the `NonServedDemand` cost category.

!!! note "Wide format naming"
    In **wide format**, the column name for each NSD variable is formed by combining the `component_id` and `segment`: `{component_id}_seg{segment}` (e.g., `elec_SE_seg1`, `elec_SE_seg2`). This allows distinguishing multiple segments for the same node when columns are pivoted.

## [Configuration](@id manual-outputs-nsd-configuration)

| Setting | File | Default | Effect |
|---|---|---|---|
| `OutputLayout` (or `OutputLayout.NonServedDemand`) | `macro_settings.json` | `"long"` | Set to `"wide"` to pivot time steps into columns with compound column names `{component_id}_seg{segment}`. |
| `WriteFullTimeseries` | `case_settings.json` | `false` | When `true` and TDR is active, also write full-year NSD to `full_time_series/non_served_demand.csv`. |

## [Assumptions](@id manual-outputs-nsd-assumptions)

- **Nodes with NSD only.** Only nodes configured with `max_nsd != [0.0]` (i.e., nodes with non-zero maximum non-served demand) produce rows. Nodes without NSD variables are excluded from this file.
- **File not written if empty.** If no node in the system has NSD variables, `non_served_demand.csv` will not be created.
- **Units.** NSD values are in the same units as the demand input for that commodity. For electricity, this is typically MWh/hour (= MW). For mass commodities, the units follow your input convention.
- **Annual NSD.** To compute total annual non-served demand, multiply `value(t) × weight(t)` from `time_weights.csv` and sum:
  ```
  Annual NSD (MWh) = Σ_{t,seg}  value(t, seg) × weight(t) × hours_per_timestep
  ```
- **NSD and infeasibility.** If NSD is not enabled on a node (`max_nsd = [0.0]`) and the optimizer cannot meet demand, the problem will be infeasible. 
- **Cost in objective.** NSD values incur penalty costs that appear under the `NonServedDemand` category in `costs_by_type.csv` and `costs_by_zone.csv`.

## [Examples](@id manual-outputs-nsd-examples)

### Default Long Format (example rows — single segment)

| commodity | zone | component\_id | component\_type | variable | segment | time | value |
|---|---|---|---|---|---|---|---|
| Electricity | SE | elec\_SE | Node{Electricity} | non\_served\_demand | 1 | 1 | 0.0 |
| Electricity | SE | elec\_SE | Node{Electricity} | non\_served\_demand | 1 | 2 | 0.0 |
| Electricity | SE | elec\_SE | Node{Electricity} | non\_served\_demand | 1 | 3 | 12.5 |

### Default Long Format (example rows — two segments)

| commodity | zone | component\_id | component\_type | variable | segment | time | value |
|---|---|---|---|---|---|---|---|
| Electricity | SE | elec\_SE | Node{Electricity} | non\_served\_demand | 1 | 3 | 100.0 |
| Electricity | SE | elec\_SE | Node{Electricity} | non\_served\_demand | 2 | 3 | 50.0 |

In this example at time step 3, the first 100 MW of demand is unmet at the segment-1 penalty price, and an additional 50 MW is unmet at the (higher) segment-2 penalty price.

### Wide Format (`OutputLayout.NonServedDemand = "wide"`)

| time | elec\_SE\_seg1 | elec\_SE\_seg2 | h2\_MIDAT\_seg1 |
|---|---|---|---|
| 1 | 0.0 | 0.0 | 0.0 |
| 2 | 0.0 | 0.0 | 0.0 |
| 3 | 100.0 | 50.0 | 0.0 |

### Computing Total Annual NSD

```julia
using CSV, DataFrames

nsd = CSV.read("results/non_served_demand.csv", DataFrame)
weights = CSV.read("results/time_weights.csv", DataFrame)

df = leftjoin(nsd, weights, on=:time)
df.annual_MWh = df.value .* df.weight

# Total annual NSD by node and segment
annual = combine(groupby(df, [:component_id, :segment]), :annual_MWh => sum)
```

## [See Also](@id manual-outputs-nsd-see-also)

- [Outputs Overview](@ref "manual-outputs-overview") — overview of all output files and settings
- [Costs Output](@ref "manual-outputs-costs") — NSD penalty costs appear under the `NonServedDemand` category
- [Full Time Series Output](@ref "manual-outputs-full-timeseries") — 8760-hour expanded NSD
- [Time Weights Output](@ref "manual-outputs-time-weights") — weights for annualizing NSD values
- [Nodes](@ref "manual-nodes-overview") — `max_nsd` and `nsd_cost` node input parameters
