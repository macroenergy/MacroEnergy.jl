# Load the demand data
function load_demand_data!(nodes::Dict{Symbol,Node}, system_dir::AbstractString)
    demand_dir = joinpath(system_dir, "demand_data")
    demand_data = load_all_ts(demand_dir)
    add_demand_to_nodes!(nodes, demand_data)

    nsd_data = load_nsd_data_json(demand_dir)
    add_nsd_to_nodes!(nodes, nsd_data)

    return nothing
end

function load_all_ts(data_dir::AbstractString)
    data = Dict{Symbol,Vector{Float64}}()
    files = filter(x -> endswith(x, ".csv"), readdir(data_dir))
    for file in files
        df = CSV.read(joinpath(data_dir, file), DataFrame)
        if intersect(propertynames(df), keys(data)) != []
            msg = "The file $(file) contains columns with the same name as other files. \n" *
            "Please make sure to have unique column names for each file. \n" *
            "The data will be loaded but the columns will be overwritten."
            @warn(msg)
        end
        merge!(data, Dict(pairs(eachcol(select!(df, Not(:Time_Index))))))
    end
    return data
end

function add_demand_to_nodes!(nodes::Dict{Symbol,Node}, demand_data::Dict{Symbol,Vector{Float64}})
    for dem_header in keys(demand_data)
        if dem_header ∉ demand_header.(values(nodes))
            msg = "A demand time series with header `$(dem_header)` was found in the demand data, \n" *
            "but it wasn't found in any of the loaded nodes. \n" *
            "Please make sure to have set the correct `demand_header` attribute in the nodes (check the `nodes.json` file inside the `system/network` directory)."
            @warn(msg)
            continue
        end
        for (_, node) in nodes
            if node.demand_header == dem_header
                node.demand = demand_data[dem_header]
            end
        end
    end
    return nothing
end

function load_nsd_data_json(demand_dir::AbstractString)
    file = "nsd_data.json"

    nsd_data = Dict{Symbol, Dict}()
    data = JSON3.read(joinpath(demand_dir, file))
    for (commodity,data_obj) in data
        nsd_data[Symbol(commodity)] = nsd_to_dict(data_obj)
    end
    return nsd_data
end

function nsd_to_dict(data_raw::JSON3.Object)
    nsd_data = Dict()
    nsd_data[:voll] = data_raw.voll
    nsd_data[:nsd_data] = [Dict(x) for x in data_raw.nsd_data]
    return nsd_data
end

function add_nsd_to_nodes!(nodes::Dict{Symbol,Node}, nsd_data::Dict{Symbol,Dict})
    macro_commodities = commodity_types()
    # loop over commodities in nsd_data
    for (commodity, data) in nsd_data
        voll = data[:voll]
        commodity = macro_commodities[commodity] # get the correct commodity type
        # for each commodity, add the nsd data to the corresponding nodes
        nodes_commodity = get_nodes_sametype(nodes, commodity)
        for node in values(nodes_commodity)
            max_nsd = Float64.([x[:max_demand_curtailment] for x in data[:nsd_data]])
            node.max_nsd = max_nsd
            price_nsd = Float64.([x[:cost_of_demand_curtailment_per_mw] for x in data[:nsd_data]])
            node.price_nsd = price_nsd .* voll
        end
    end
    return nothing
end


            