Base.@kwdef mutable struct Location <: MacroObject
    id::Symbol
    system::AbstractSystem
    nodes::Dict{Symbol,Node} = Dict{Symbol,Node}()
    commodities::Set{Symbol} = Set{Symbol}()
    constraints::Vector{AbstractTypeConstraint} = AbstractTypeConstraint[]
    # We could change this to work on commodities, not symbols
    # My feeling is that symbols will be lighter and faster
end

"""
    LocationInput(; id, constraints=Dict{Symbol,Any}())

Validated inputs consumed when constructing a `Location`. `id` is a required,
nonempty string; `constraints` contains raw constraint input dictionaries/flags.
Constraint instances and typed configs are created when building the `Location`.
Raw input dictionaries remain extensible: additional fields may be consumed by
builders without becoming fields of this type.
"""
Base.@kwdef struct LocationInput
    id::String
    constraints::Dict{Symbol,Any} = Dict{Symbol,Any}()

    function LocationInput(id::AbstractString, constraints::AbstractDict)
        isempty(strip(id)) && throw(ArgumentError("Location `id` must be a nonempty string"))
        all(key -> key isa Union{Symbol,AbstractString}, keys(constraints)) ||
            throw(ArgumentError("Location constraint names must be strings or symbols"))
        constraint_data = Dict{Symbol,Any}(Symbol(key) => value for (key, value) in constraints)
        return new(String(id), constraint_data)
    end

    function LocationInput(id, constraints)
        id isa AbstractString || throw(ArgumentError("Location `id` must be a string"))
        constraints isa AbstractDict || throw(ArgumentError("Location `constraints` must be a dictionary"))
        throw(ArgumentError("Unsupported inputs for Location $id"))
    end
end

function Location(input::LocationInput, system::AbstractSystem)
    data = Dict{Symbol,Any}(:constraints => input.constraints)
    check_and_convert_constraints!(data)
    validate_required_constraint_configs!(data[:constraints], "location `$(input.id)`")
    return Location(; id=Symbol(input.id), system=system, constraints=data[:constraints])
end

id(loc::Location) = loc.id
all_constraints(loc::Location) = loc.constraints

function add_node!(loc::Location, node::Node{T}, replace::Bool = false) where {T<:Commodity}
    node_commodity = typesymbol(commodity_type(node))
    # If a node of the same type exists then throw an error unless replace is true
    if ((node_commodity in loc.commodities) || (node_commodity in keys(loc.nodes))) && !replace
        error("A $node_commodity node already exists in the $(loc.id) location")
    end
    node.location = loc.id
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

function parse_location_input(entry, index::Integer=1)
    context = "Location entry $index"
    if entry isa AbstractString
        data = Dict{Symbol,Any}(:id => entry)
    elseif entry isa AbstractDict
        all(key -> key isa Union{Symbol,AbstractString}, keys(entry)) ||
            throw(ArgumentError("$context must use string or symbol keys"))
        data = Dict{Symbol,Any}(Symbol(key) => value for (key, value) in entry)
    else
        throw(ArgumentError("$context must be an object with an `id` field or a location name string"))
    end
    return LocationInput(;
        id = haskey(data, :id) ? data[:id] : throw(ArgumentError("$context requires an `id` field")),
        constraints = get(data, :constraints, Dict{Symbol,Any}()),
    )
end

function load_locations!(system::AbstractSystem, rel_or_abs_path::String, data::AbstractVector)
    locations = Location[]
    for (index, entry) in enumerate(data)
        input = parse_location_input(entry, index)
        push!(locations, Location(input, system))
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
