struct MyopicResults
    results::Union{Vector, Nothing}
    output_path::String
end

function load_previous_capacity_results(path::AbstractString)
    df = load_dataframe(path)
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
