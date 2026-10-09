# [Losses Output](@id manual-outputs-losses)

## Contents

[Overview](@ref "manual-outputs-losses-overview") | [Columns](@ref "manual-outputs-losses-columns") | [Calculation](@ref "manual-outputs-losses-calculation") | [Configuration](@ref "manual-outputs-losses-configuration") | [Assumptions](@ref "manual-outputs-losses-assumptions") | [Examples](@ref "manual-outputs-losses-examples") | [See Also](@ref "manual-outputs-losses-see-also")

## [Overview](@id manual-outputs-losses-overview)

**File:** `losses.csv`

`losses.csv` records the commodity lost on every edge with a nonzero `loss_fraction` (e.g. a lossy transmission line) at every representative time step.

!!! note "Losses are a derived quantity"
    Losses are **not** an optimization variable. They are computed after the solve from the optimal values of the edge's flow variables.

## [Columns](@id manual-outputs-losses-columns)

| Column | Type | Description |
|---|---|---|
| `commodity` | String | Commodity carried by the edge |
| `node_in` | String | Start vertex of the edge |
| `node_out` | String | End vertex of the edge |
| `resource_id` | String | Unique identifier of the parent asset |
| `component_id` | String | Unique identifier of the edge |
| `resource_type` | String | Asset type (e.g., `TransmissionLink{Electricity}`) |
| `component_type` | String | Type of the edge (e.g., `BidirectionalEdge{Electricity}`) |
| `variable` | String | Always `"loss"` |
| `time` | Int | Representative time step index (1-based integer, matches `time` in other output files) |
| `value` | Float64 | Commodity lost at this time step, in the same units as `flows.csv` (default: MW for electricity) |

## [Calculation](@id manual-outputs-losses-calculation)

For a **unidirectional** edge, the loss at time step $t$ is taken from the flow arriving at the end vertex:

```math
\text{loss}(t) = \text{loss\_fraction}(t) \times \text{flow}(t)
```

A lossy **bidirectional** edge splits its flow into two nonnegative parts, $\text{flow}(t) = \text{flow\_pos}(t) - \text{flow\_neg}(t)$. The end vertex receives $(1 - \text{loss\_fraction}(t))\,\text{flow\_pos}(t)$ and the start vertex receives $(1 - \text{loss\_fraction}(t))\,\text{flow\_neg}(t)$, so:

```math
\text{loss}(t) = \text{loss\_fraction}(t) \times \big(\text{flow\_pos}(t) + \text{flow\_neg}(t)\big)
```

The model does not force one of `flow_pos` and `flow_neg` to be zero. When both are positive in the same time step, the edge dissipates commodity at both vertices, and the loss is larger than $\text{loss\_fraction}(t) \times |\text{flow}(t)|$. For this reason the loss cannot be recovered from `flows.csv` alone.

!!! tip "Annual losses"
    To compute total annual losses for an edge, multiply `value(t) × weight(t)` and sum over all time steps, where `weight(t)` comes from `time_weights.csv`:
    ```
    Annual losses (MWh) = Σ_t  loss(t) × weight(t) × hours_per_timestep
    ```

## [Configuration](@id manual-outputs-losses-configuration)

| Setting | File | Default | Effect |
|---|---|---|---|
| `OutputLayout` (or `OutputLayout.Losses`) | `macro_settings.json` | `"long"` | Set to `"wide"` to pivot time steps into rows and edges (`component_id`) into columns. |
| `WriteFullTimeseries` | `case_settings.json` | `false` | When `true` and TDR is active, also write full-year losses to `full_time_series/losses.csv`. |

## [Assumptions](@id manual-outputs-losses-assumptions)

- **Every lossy edge.** All edges with `loss_fraction > 0` in at least one time step are included, whatever asset they belong to. Edges without losses do not produce rows.
- **File not written if empty.** If no edge in the system has a nonzero `loss_fraction`, `losses.csv` is not written.

## [Examples](@id manual-outputs-losses-examples)

### Default Long Format (example rows)

| commodity | node\_in | node\_out | resource\_id | component\_id | resource\_type | component\_type | variable | time | value |
|---|---|---|---|---|---|---|---|---|---|
| Electricity | elec\_MA | elec\_CT | MA\_to\_CT | MA\_to\_CT\_transmission\_edge | TransmissionLink{Electricity} | BidirectionalEdge{Electricity} | loss | 1 | 20.0 |
| Electricity | elec\_MA | elec\_CT | MA\_to\_CT | MA\_to\_CT\_transmission\_edge | TransmissionLink{Electricity} | BidirectionalEdge{Electricity} | loss | 2 | 0.0 |

### Computing Annual Losses

```julia
using CSV, DataFrames

losses = CSV.read("results/losses.csv", DataFrame)
weights = CSV.read("results/time_weights.csv", DataFrame)

df = leftjoin(losses, weights, on=:time)
df.annual_MWh = df.value .* df.weight

annual_by_edge = combine(groupby(df, :component_id), :annual_MWh => sum => :annual_losses_MWh)
```

## [See Also](@id manual-outputs-losses-see-also)

- [Outputs Overview](@ref "manual-outputs-overview") — overview of all output files and settings
- [Flows Output](@ref "manual-outputs-flows") — net edge flows (`flow_pos - flow_neg` for bidirectional edges)
- [Full Time Series Output](@ref "manual-outputs-full-timeseries") — 8760-hour expanded losses
- [Time Weights Output](@ref "manual-outputs-time-weights") — weights for annualizing losses
