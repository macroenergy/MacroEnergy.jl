"""
    write_time_weights(results_dir::AbstractString, system::System)

Write the subperiod weight for each modeled timestep to `time_weights.csv`.

This function ensures that the time index in the output matches the exact
`t` values used in flow outputs (via `time_interval(obj)`), which may be
non-contiguous (e.g., 169–336, 337–504) when running subperiod models.

# Output
Creates `time_weights.csv` with columns:
- `time`: actual modeled timestep index used in the optimization
- `weight`: subperiod weight assigned to that timestep

The output aligns with flow files created by `get_optimal_flow`, ensuring
consistent indexing across all subperiod results.
"""
function write_time_weights(results_dir::AbstractString, system::System)
    @info "Writing time weights to $results_dir"

    filename = "time_weights.csv"
    file_path = joinpath(results_dir, filename)

    # Select a reference node to get:
    #  - time_interval (modelled time axis)
    #  - subperiod map
    ref_node = first(filter(n -> n isa Node, system.locations))

    # Actual model time axis (matches flow outputs)
    t_axis = collect(time_interval(ref_node))

    # Weight for each timestep t
    weights = [
        subperiod_weight(ref_node, current_subperiod(ref_node, t))
        for t in t_axis
    ]

    df = DataFrame(time = t_axis, weight = weights)

    CSV.write(file_path, df)

    return nothing
end
