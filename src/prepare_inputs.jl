function prepare_inputs!(setup::Dict)

    PeriodLength = setup["PeriodLength"]

    hours_per_subperiod = setup["hours_per_subperiod"]

    hours_per_timestep =
        Dict(c => setup[c]["hours_per_timestep"] for c in setup["commodities"])

    timesteps_map =
        Dict(c => 1:hours_per_timestep[c]:PeriodLength for c in setup["commodities"])

    subperiod_map = Dict(
        c => collect(
            Iterators.partition(
                timesteps_map[c],
                Int(hours_per_subperiod / hours_per_timestep[c]),
            ),
        ) for c in setup["commodities"]
    )

    setup["subperiod_map"] = subperiod_map

    setup["timesteps_map"] = timesteps_map

    return loadresources(setup), loadedges(setup), loadnodes(setup)#,loadtransformations(setup)
end

function makeresource(
    c::DataType,
    row::DataFrameRow,
    timesteps::StepRange{Int64,Int64},
    subperiods::Vector{StepRange{Int64,Int64}},
)

    if row.storage == 0
        return Resource{c}(
            node = row.node,
            r_id = row.r_id,
            timesteps = timesteps,
            subperiods = subperiods,
            investment_cost = row.investment_cost,
            fixed_om_cost = row.fixed_om_cost,
            capacity_factor = ones(length(timesteps)),
            price = zeros(length(timesteps)),
        )
    elseif row.storage == 1
        return SymmetricStorage{c}(
            node = row.node,
            r_id = row.r_id,
            timesteps = timesteps,
            subperiods = subperiods,
            investment_cost = row.investment_cost,
            fixed_om_cost = row.fixed_om_cost,
            capacity_factor = ones(length(timesteps)),
            price = zeros(length(timesteps)),
        )
    elseif row.storage == 2
        return AsymmetricStorage{c}(
            node = row.node,
            r_id = row.r_id,
            timesteps = timesteps,
            subperiods = subperiods,
            investment_cost = row.investment_cost,
            fixed_om_cost = row.fixed_om_cost,
            capacity_factor = ones(length(timesteps)),
            price = zeros(length(timesteps)),
        )
    end

end


# function maketransformation(row::DataFrameRow,setup::Dict)

#     number_of_commodities = length(setup["commodities"]);

#     return Transformation(id = row.id,
#         nodes = Dict(commodity_type(row[Symbol("commodity_$i")])=>row[Symbol("node_$i")] for i in 1:number_of_commodities), 
#         stoichiometry = Dict(commodity_type(row[Symbol("commodity_$i")])=>row[Symbol("stoichiometry_$i")] for i in 1:number_of_commodities),
#         direction =  Dict(commodity_type(row[Symbol("commodity_$i")])=>row[Symbol("direction_$i")] for i in 1:number_of_commodities), 
#         timesteps = Dict(commodity_type(row[Symbol("commodity_$i")])=>setup["timesteps_map"][commodity_type(row[Symbol("commodity_$i")])] for i in 1:number_of_commodities), 
#         subperiods = Dict(commodity_type(row[Symbol("commodity_$i")])=>setup["subperiod_map"][commodity_type(row[Symbol("commodity_$i")])] for i in 1:number_of_commodities), 
#     )

# end


function makeedge(c::DataType, row::DataFrameRow, timesteps::StepRange{Int64,Int64})

    return Edge{c}(
        start_node = row.start_node,
        end_node = row.end_node,
        existing_capacity = row.existing_capacity,
        timesteps = timesteps,
    )

end

function makenode(c::DataType, row::DataFrameRow, timesteps::StepRange{Int64,Int64})

    return Node{c}(
        id = row.id,
        demand = collect(row[2+first(timesteps):2+last(timesteps)]),
        max_nsd = row.max_nsd,
        timesteps = timesteps,
    )

end

function loadresources(setup::Dict)
    resources = AbstractResource[]

    for c in setup["commodities"]
        filepath = setup[c]["resource_filepath"]
        if !ismissing(filepath)
            nt = length(setup["timesteps_map"][c])
            df = CSV.read(filepath, DataFrame)
            for row in eachrow(df)
                push!(
                    resources,
                    makeresource(
                        c,
                        row,
                        setup["timesteps_map"][c],
                        setup["subperiod_map"][c],
                    ),
                )
            end
        end
    end
    return resources
end


function loadedges(setup::Dict)
    edges = AbstractEdge[]

    for c in setup["commodities"]
        filepath = setup[c]["edge_filepath"]
        if !ismissing(filepath)
            df = CSV.read(filepath, DataFrame)
            for row in eachrow(df)
                push!(edges, makeedge(c, row, setup["timesteps_map"][c]))
            end
        end
    end
    return edges
end

function loadnodes(setup::Dict)
    nodes = AbstractNode[]

    for c in setup["commodities"]
        filepath = setup[c]["node_filepath"]
        if !ismissing(filepath)
            df = CSV.read(filepath, DataFrame)
            for row in eachrow(df)
                push!(nodes, makenode(c, row, setup["timesteps_map"][c]))
            end
        end
    end
    return nodes
end

# function loadtransformations(setup::Dict)

#     transformations = AbstractTransformation[]
#     filepath = setup["transformation_filepath"];

#     if !ismissing(filepath)
#         df = CSV.read(filepath, DataFrame)
#         for row in eachrow(df)
#             push!(transformations, maketransformation(row,setup))
#         end
#     end

#     return transformations
# end
