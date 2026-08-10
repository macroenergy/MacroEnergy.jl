"""
Sub-period weight outputs — maps each timestep to its TDR representative-period weight.
"""

"""
    write_time_weights(file_path, system)

Write a CSV that maps every optimization timestep index to the weight of its representative
sub-period.

## Weights and TDR

When time-domain reduction (TDR) is used, many full-year sub-periods are clustered into a
smaller set of representative periods. The `weight` of a representative period equals the
number of full-year sub-periods it represents, scaled so that the weighted sum of hours
equals `TotalHoursModeled` (typically 8760). All timesteps within the same representative
sub-period share the same weight. So, the `weight` of a timestep is the number of hours 
that timestep represents when annualizing: multiplying flow(t) × weight(t) and summing over 
t yields the full-year equivalent.

Weights are normalized so that:
```
Σ_k  weight(k) × hours_per_subperiod(k)  =  TotalHoursModeled
```
where `hours_per_subperiod(k)` is the length of subperiod k in hours. 

Without TDR (single representative sub-period), every timestep receives weight 1.0. However, 
if `TotalHoursModeled` differs from the sum of timestep durations in the model
(e.g., partial-year or leap-year), the same normalization applies: weights scale so the
formula above holds, keeping annualization consistent across configurations.


## Output columns
- `time` — timestep index (1-based integer, matching the `time` column in other outputs)
- `subperiod_index` — index of the representative sub-period that the timestep belongs to
- `weight` — weight of the representative sub-period (hours it represents in the full year)

## Usage
```julia
write_time_weights(joinpath(results_dir, "time_weights.csv"), system)
```

Weights are used downstream to compute weighted annual sums, e.g. energy revenue:
```
EnergyRevenue = Σ_t  flow(t) × price(t) × weight(t)
```
"""
function write_time_weights(file_path::AbstractString, system::System)
    @info "Writing time weights to $file_path"

    # All commodities share the same time structure; use the first available one.
    td = system.time_data[first(keys(system.time_data))]

    times = collect(td.time_interval)

    # For each timestep t, find which representative sub-period it belongs to.
    # td.subperiods is a Vector{StepRange} — one range per representative period.
    # td.subperiod_indices[k] is the index of the k-th representative sub-period.
    # td.subperiod_weights[i] is the weight for representative period index i.
    subperiod_index_col = Int[]
    weight_col = Float64[]
    for t in times
        k = findfirst(t .∈ td.subperiods)
        rep_period = td.subperiod_indices[k]
        push!(subperiod_index_col, rep_period)
        push!(weight_col, td.subperiod_weights[td.subperiod_map[rep_period]])
    end

    df = DataFrame(
        time            = times,
        subperiod_index = subperiod_index_col,
        weight          = weight_col,
    )

    write_dataframe(file_path, df)
    return nothing
end
