struct MyopicResults
    results::Union{Vector, Nothing}
    output_path::String
    outcomes::Vector{PeriodOutcome} # Termination status of each period
end

MyopicResults(results, output_path) = MyopicResults(results, output_path, PeriodOutcome[])

"""
    check_myopic_capacity_outputs(periods::Vector{System}, myopic_settings)

Check that a Myopic run writes the capacity files that a later restart reads. If the run stops
early (`StopAfterPeriod` before the last period), it is meant to be continued, so
`WriteOutputs.Capacity = false` for any period it writes is an error. For a run that goes to
the last period, it is only a warning.
"""
function check_myopic_capacity_outputs(periods::Vector{System}, myopic_settings)
    restart = myopic_settings[:Restart]
    first_period = restart[:enabled] ? restart[:from_period] : 1
    last_period = floor(Int, min(length(periods), myopic_settings[:StopAfterPeriod]))
    no_capacity = [p for p in first_period:last_period if !output_enabled(periods[p], :Capacity)]
    isempty(no_capacity) && return nothing
    if last_period < length(periods)
        error("WriteOutputs.Capacity is false for period(s) $(join(no_capacity, ", ")), but this Myopic run stops " *
              "after period $last_period of $(length(periods)) (StopAfterPeriod). Restarting it later needs the " *
              "capacity file of every period: enable the Capacity output for these periods.")
    end
    @warn("WriteOutputs.Capacity is false for period(s) $(join(no_capacity, ", ")): the results of this run " *
          "cannot be used to restart a later Myopic run.")
    return nothing
end

function load_previous_capacity_results(path::AbstractString)
    # Plain CSV keeps the header validation of load_dataframe; DuckDB reads .csv.gz and .parquet
    df = endswith(path, ".csv") ? load_dataframe(path) : duckdb_read(path)
    if all(["component_id", "capacity", "new_capacity", "retired_capacity"] .∈ Ref(names(df)))
        #### The dataframe has wide format
        return df
    elseif all(["component_id", "variable", "value"] .∈ Ref(names(df)))
        #### The dataframe has long format, reshape to wide
        return reshape_wide(df, :variable, :value)
    else
        error("The capacity results file at $(path) does not have the expected format. It should contain either (component_id, capacity, new_capacity, retired_capacity) columns in wide format or (component_id, variable, value) columns in long format.")
    end
end

function carry_over_capacities!(system::System, prev_results::Dict{Int64,DataFrame}, last_period::Int, scaling::Real=1.0)

    # Capacities in the restart `capacity.csv` files are in original units (the
    # output writers already undid scaling), but the System about to be built is
    # scaled. Divide the loaded values by `scaling` so they match the scaled
    # model. No-op when scaling is disabled (`scaling == 1.0`).
    all_edges = get_edges(system)
    storages = get_storages(system)
    edges_with_capacity = edges_with_capacity_variables(all_edges)
    components_with_capacity = vcat(edges_with_capacity, storages)
    for y in components_with_capacity
        df_restart = prev_results[last_period]
        component_row = findfirst(df_restart.component_id .== String(id(y)))
        if isnothing(component_row)
            @info("Skipping component $(id(y)) as it was not present in the previous period")
        else
            y.existing_capacity = df_restart.capacity[component_row] / scaling
            for prev_period in keys(prev_results)
                df = prev_results[prev_period];
                component_row = findfirst(df.component_id .== String(id(y)))
                if !isnothing(component_row)
                    y.new_capacity_track[prev_period] = df.new_capacity[component_row] / scaling
                    y.retired_capacity_track[prev_period] = df.retired_capacity[component_row] / scaling
                    if isa(y, AbstractEdge) && "retrofitted_capacity" ∈ names(df)
                        y.retrofitted_capacity_track[prev_period] = df.retrofitted_capacity[component_row] / scaling
                    end
                end
            end
        end
    end
end
