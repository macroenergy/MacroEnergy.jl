function load_inputs(settings::NamedTuple, input_path::AbstractString)

    system_path = joinpath(input_path, "system")

    # Read in all the commodities
    commodities = load_commodities_json(system_path)

    # Read in time data
    time_data = load_time_json(system_path, commodities)

    # Read in all the nodes
    network_dir = joinpath(system_path, "network")
    nodes = load_nodes_json(network_dir, time_data)

    # Read in demand data
    load_demand_data!(nodes, system_path)

    # Create the network (aka Edges) between Nodes
    edges = load_edges_json(network_dir, time_data, nodes)
    
    # Load all the asset data
    asset_dir = joinpath(input_path, "assets")
    assets = load_assets_json(asset_dir, time_data, nodes)

    # Load the capacity factor data for the assets
    load_capacity_factor!(assets, asset_dir)

    # Read in fuel data
    load_fuel_data!(system_path, assets)

    return (commodities=commodities, time_data=time_data, nodes=nodes, edges=edges, assets=assets)
end

function validate_id!(data::Dict{Symbol,Any})
    if !haskey(data, :id)
        throw(ArgumentError("TEdge data must have an id"))
    end
    return nothing
end

function validate_direction!(data::Dict{Symbol,Any})
    if haskey(data, :direction) && data[:direction] ∉ [:input, :output]
        if data[:direction] == "input"
            data[:direction] = :input
        elseif data[:direction] == "output"
            data[:direction] = :output
        else
            throw(ArgumentError("Invalid direction: $(data[:direction]) for TEdge $(data[:id])"))
        end        
    end
    return nothing
end

function validate_vector_symbol!(data::Dict{Symbol,Any}, key::Symbol)
    if haskey(data, key) && !isa(data[key], Vector{Symbol})
        data[key] = Symbol.(data[key])
    end
    return nothing
end

function validate_single_symbol!(data::Dict{Symbol,Any}, key::Symbol)
    if haskey(data, key) && !isa(data[key], Symbol)
        data[key] = Symbol(data[key])
    end
    return nothing
end

function validate_fuel_stoichiometry_name!(data::Dict{Symbol,Any})
    validate_single_symbol!(data, :fuel_stoichiometry_name)
    validate_vector_symbol!(data, :fuel_stoichiometry_name)
    return nothing
end

function validate_stoichiometry_balance_names!(data::Dict{Symbol,Any})
    validate_vector_symbol!(data, :stoichiometry_balance_names)
    return nothing
end

function validate_constraints_data!(data::Dict{Symbol,Any})
    if haskey(data, :constraints) 
        constraints = Dict{Symbol,Any}()
        for (k,v) in data[:constraints]
            new_k = Symbol(join(push!(uppercasefirst.(split(string(k), "_")),"Constraint")))
            constraints[new_k] = v
        end
        data[:constraints] = constraints
    end
    return nothing 
end

function validate_demand_header!(data::Dict{Symbol,Any})
    validate_single_symbol!(data, :demand_header)
    return nothing
end

function validate_fuel_header!(data::Dict{Symbol,Any})
    validate_single_symbol!(data, :price_header)
    return nothing
end

function validate_max_line_reinforcement!(data::Dict{Symbol,Any})
    if haskey(data, :max_line_reinforcement)
        # Convert "Inf" to Inf
        max_line_reinforcement = get(data, :max_line_reinforcement, Inf)
        data[:max_line_reinforcement] = max_line_reinforcement == "Inf" ? Inf : max_line_reinforcement
    end
    return nothing
end

function validate_rhs_policy!(data::Dict{Symbol,Any})
    if haskey(data, :rhs_policy)
        rhs_policy = Dict{DataType,Float64}()
        constraints = constraint_types()
        for (k,v) in data[:rhs_policy]
            new_k = constraints[Symbol(k)]
            rhs_policy[new_k] = v
        end
        data[:rhs_policy] = rhs_policy
    end
    return nothing
end

function validate_data!(data::Dict{Symbol,Any})
    validate_id!(data)
    validate_direction!(data)
    validate_fuel_stoichiometry_name!(data)
    validate_stoichiometry_balance_names!(data)
    validate_constraints_data!(data)
    validate_max_line_reinforcement!(data)
    validate_demand_header!(data)
    validate_fuel_header!(data)
    validate_rhs_policy!(data)
    return nothing
end

function get_tedge_data(data::Dict{Symbol,Any}, id::Symbol, immutable::Bool=false)
    for (edge_id, edge_data) in data[:edges]
        if edge_id == id || edge_data[:type] == string(id)
            immutable && return edge_data
            return copy(edge_data)
        end
    end
    return nothing
end