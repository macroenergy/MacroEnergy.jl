Base.@kwdef mutable struct Location <: MacroObject
    id::Symbol
    system::AbstractSystem
    nodes::Dict{Symbol,Node} = Dict{Symbol,Node}()
    commodities::Set{Symbol} = Set{Symbol}()
    # We could change this to work on commodities, not symbols
    # My feeling is that symbols will be lighter and faster
end

id(loc::Location) = loc.id

function add_node!(loc::Location, node::Node{T}, replace::Bool = false) where {T<:Commodity}
    node_commodity = typesymbol(commodity_type(node))
    # If a node of the same type exists then throw an error unless replace is true
    if ((node_commodity in loc.commodities) || (node_commodity in keys(loc.nodes))) &&
       !replace
        error("A $node_commodity node already exists in the $(loc.id) location")
    end
    loc.nodes[node_commodity] = node
    push!(loc.commodities, node_commodity)
end

function refresh_commodities_list!(loc::Location)
    loc.commodities =
        Set{Symbol}(typesymbol(commodity_type(node)) for node in values(loc.nodes))
end

function load_locations!(system::AbstractSystem, rel_or_abs_path::String, data::AbstractString)
    return load_locations!(system, rel_or_abs_path, [data])
end

function load_locations!(system::AbstractSystem, rel_or_abs_path::String, data::Vector{<:AbstractString})
    locations = Location[]
    for loc_id in data
        # In the future, we could pre-emptively find the relevant nodes
        push!(locations, Location(;id=Symbol(loc_id), system=system))
    end
    system.locations = locations
    return nothing
end

function load_locations!(system::AbstractSystem, rel_or_abs_path::String, data::AbstractDict{Symbol, Any})
    if haskey(data, :path)
        data = eager_load_json_inputs(data, rel_or_abs_path)
        if isa(data, AbstractDict) && haskey(data, :locations) && !isempty(data[:locations])
            load_locations!(system, rel_or_abs_path, data[:locations])
        end
    else
        error("Location data is not in the expected format")
    end
    return nothing
end

function add_linking_variables!(location::Location, model::Model)
    return nothing
end

function define_available_capacity!(location::Location, model::Model)
    # FIXME to return capacities?
    return nothing
end

function planning_model!(location::Location, model::Model)
    return nothing
end

function operation_model!(location::Location, model::Model)
    return nothing
end