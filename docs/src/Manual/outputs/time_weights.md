# [Time Weights Output](@id manual-outputs-time-weights)

## Contents

[Overview](@ref "manual-outputs-time-weights-overview") | [Columns](@ref "manual-outputs-time-weights-columns") | [How Weights Are Calculated](@ref "manual-outputs-time-weights-calculation") | [Using Weights](@ref "manual-outputs-time-weights-usage") | [Examples](@ref "manual-outputs-time-weights-examples") | [See Also](@ref "manual-outputs-time-weights-see-also")

## [Overview](@id manual-outputs-time-weights-overview)

**File:** `time_weights.csv`

`time_weights.csv` maps every optimization time step to the number of full-year hours it represents. This file is essential for converting representative-period results (flows, storage levels, curtailment, non-served demand) into annual totals.

When **time-domain reduction (TDR)** is used, the full year (typically 8,760 hours) is compressed into a smaller set of representative periods. Each representative period stands in for multiple full-year periods. The weight of a time step encodes how many full-year hours that time step represents — allowing weighted sums over the representative period to recover annual totals accurately.

Without TDR (i.e., when all time steps are modeled directly), every time step receives a weight of `1.0`, and the weighted sum equals a simple unweighted sum.

## [Columns](@id manual-outputs-time-weights-columns)

| Column | Type | Description |
|---|---|---|
| `time` | Int | Time step index (1-based integer, matches the `time` column in `flows.csv`, `storage_level.csv`, `curtailment.csv`, and `non_served_demand.csv`) |
| `subperiod_index` | Int | Index of the representative sub-period this time step belongs to (1-based). All time steps within the same representative sub-period share the same `subperiod_index` and `weight`. |
| `weight` | Float64 | Number of full-year sub-periods represented by this representative sub-period. All time steps in the same representative sub-period share this weight. |

## [How Weights Are Calculated](@id manual-outputs-time-weights-calculation)

Weights are normalized so that the weighted sum of hours equals `TotalHoursModeled` (typically 8,760):

```math
\sum_{k} \text{weight}(k) \times \text{hours\_per\_subperiod}(k) = \text{TotalHoursModeled}
```

where the sum is over all representative sub-periods $k$, and `hours_per_subperiod` is the number of time steps in each sub-period.

**Example:** If the full year has 52 weekly sub-periods (each 168 hours) and TDR selects 3 representative weeks:
- Representative week A is chosen to represent 21 actual weeks → `weight = 21.05775`
- Representative week B represents 18 weeks → `weight = 18.0495`
- Representative week C represents 13 weeks → `weight = 13.03575`
- Check: $21.05775 \times 168 + 18.0495 \times 168 + 13.03575 \times 168 = 52.143 \times 168 = 8760$ ✓

All 168 time steps within representative week A share `weight = 21.05775`; all steps within week B share `weight = 18.0495`, etc.

For a detailed explanation of representative periods and TDR, see [Time Data](@ref "Time Data").

## [Using Weights](@id manual-outputs-time-weights-usage)

The most common use of `time_weights.csv` is to convert time-step-level values from representative periods into annual totals:

### Annual energy (MWh)

For any flow or curtailment variable, the annual energy equivalent is:

```math
\text{Annual energy} = \sum_{t} \text{value}(t) \times \text{weight}(t) \times \text{hours\_per\_timestep}
```

where `hours_per_timestep` is typically 1 (for hourly resolution models).

### Annual revenue

```math
\text{Revenue} = \sum_{t} \text{flow}(t) \times \text{price}(t) \times \text{weight}(t)
```

where `price(t)` is the locational marginal price from `balance_duals.csv`.

!!! note "Weights are sub-period weights, not timestep weights"
    All time steps within the same representative sub-period share the same weight. The weight is a property of the sub-period, not the individual time step. This is why `subperiod_index` is included in the output — it tells you which representative sub-period each time step belongs to.

## [Examples](@id manual-outputs-time-weights-examples)

### Example Output (3 representative weeks of 168 hours each)

| time | subperiod\_index | weight |
|---|---|---|
| 1 | 7 | 21.05775 |
| 2 | 7 | 21.05775 |
| … | … | … |
| 168 | 7 | 21.05775 |
| 169 | 15 | 18.0495 |
| 170 | 15 | 18.0495 |
| … | … | … |
| 336 | 15 | 18.0495 |
| 337 | 42 | 13.03575 |
| … | … | … |
| 504 | 42 | 13.03575 |

Here, time steps 1–168 belong to representative sub-period 7 (which stands for 21 actual weeks), time steps 169–336 belong to sub-period 15 (18 weeks), and time steps 337–504 belong to sub-period 42 (13 weeks).

### Computing Annual Electricity Generation

```julia
using CSV, DataFrames

flows = CSV.read("results/flows.csv", DataFrame)
weights = CSV.read("results/time_weights.csv", DataFrame)

# Join weights to flows
df = leftjoin(flows, weights, on=:time)

# Annual MWh per component (assuming hourly timesteps, hours_per_timestep = 1)
df.annual_MWh = df.value .* df.weight
annual = combine(groupby(df, [:resource_id, :component_id]), :annual_MWh => sum)
```

### Checking Weight Consistency

```julia
using CSV, DataFrames

weights = CSV.read("results/time_weights.csv", DataFrame)
hours_per_subperiod = 168  # for weekly sub-periods

# Should equal TotalHoursModeled (e.g., 8760 for 52 weeks × 168 hours)
total_hours = sum(combine(groupby(weights, :subperiod_index), :weight => first => :w).w .* hours_per_subperiod)
```

## [See Also](@id manual-outputs-time-weights-see-also)

- [Outputs Overview](@ref "manual-outputs-overview") — overview of all output files and settings
- [Flows Output](@ref "manual-outputs-flows") — time-step-level flows to be weighted
- [Storage Level Output](@ref "manual-outputs-storage-level") — time-step-level storage levels
- [Curtailment Output](@ref "manual-outputs-curtailment") — time-step-level curtailment values
- [Non-Served Demand Output](@ref "manual-outputs-nsd") — time-step-level NSD values
- [Balance Duals Output](@ref "manual-outputs-duals") — locational marginal prices (for revenue calculations)
- [Full Time Series Output](@ref "manual-outputs-full-timeseries") — full-year outputs (alternative to manual weighting)
- [Time Data](@ref "Time Data") — detailed explanation of representative periods, TDR, and the `TimeData` struct
