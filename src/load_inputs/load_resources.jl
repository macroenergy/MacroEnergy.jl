function load_resources(
    filepath::AbstractString,
    nodes::Dict{Symbol,Node},
    commodity,
    timesteps::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)

    df_resources = load_dataframe(filepath)

    adjust_cols_names!(df_resources)
    adjust_cols_types!(df_resources)

    resource_id = Symbol.(popat_col!(df_resources, :id))
    node_id = Symbol.(popat_col!(df_resources, :node))

    # output: vector of structs
    resources = Vector{Resource}(undef, length(eachrow(df_resources)))

    # loop over dataframe rows and create a resource for each row
    for (i, row) in enumerate(eachrow(df_resources))
        resources[i] = Resource{commodity}(;
            id = resource_id[i],
            node = nodes[node_id[i]],
            timesteps = timesteps,
            subperiods = subperiods,
            row...,
        )
    end

    return resources
end

function adjust_cols_names!(df::DataFrame)
    rename!(df, Symbol.(lowercase.(names(df))))
end

# only r_id and node are Int64
function adjust_cols_types!(df::DataFrame)
    cols = [col for col in names(df, Int) if col != "node"]
    df[!, cols] = float.(df[!, cols])
end

function commodity_type(c::AbstractString)
    T = eval(Symbol(c))
    @assert (T <: Commodity)
    return T
end
