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
    LocationInput(; id, constraints=Dict{Symbol,Any}(), commodities=Dict())

Validated inputs consumed when constructing a `Location`. `id` is a required,
nonempty string; `constraints` contains raw constraint input dictionaries/flags.
Constraint instances and typed configs are created when building the `Location`.
`commodities` maps commodity names to node input dictionaries. Empty dictionaries
use node defaults and an ID of `<location>_<commodity>`.
Input dictionaries use symbol keys, as produced by the JSON reader. String values
such as IDs and paths are unchanged; opaque extension payloads keep their own keys.
Raw input dictionaries remain extensible: additional fields may be consumed by
builders without becoming fields of this type.
"""
Base.@kwdef struct LocationInput
    id::String
    constraints::Dict{Symbol,Any} = Dict{Symbol,Any}()
    commodities::Dict{Symbol,Dict{Symbol,Any}} = Dict{Symbol,Dict{Symbol,Any}}()

    function LocationInput(id::AbstractString, constraints::AbstractDict, commodities::AbstractDict)
        isempty(strip(id)) && throw(ArgumentError("Location `id` must be a nonempty string"))
        validate_location_input_keys(constraints, "Location constraints")
        constraint_data = Dict{Symbol,Any}(constraints)
        validate_location_input_keys(commodities, "Location `$id` commodities")
        commodity_data = Dict{Symbol,Dict{Symbol,Any}}()
        for (name, details) in commodities
            !isempty(strip(string(name))) ||
                throw(ArgumentError("Location `$id` commodity names must be nonempty symbols"))
            haskey(commodity_data, name) && throw(ArgumentError("Duplicate commodity `$name` in location `$id`"))
            details isa AbstractDict || throw(ArgumentError("Location `$id` commodity `$name` details must be a dictionary"))
            context = "Location `$id` commodity `$name` details"
            validate_location_input_keys(details, context)
            commodity_data[name] = Dict{Symbol,Any}(details)
        end
        return new(String(id), constraint_data, commodity_data)
    end

    function LocationInput(id, constraints, commodities)
        id isa AbstractString || throw(ArgumentError("Location `id` must be a string"))
        constraints isa AbstractDict || throw(ArgumentError("Location `constraints` must be a dictionary"))
        commodities isa AbstractDict || throw(ArgumentError("Location `commodities` must be a dictionary"))
        throw(ArgumentError("Unsupported inputs for Location $id"))
    end
end

LocationInput(id, constraints) = LocationInput(id, constraints, Dict())

function validate_location_input_keys(data::AbstractDict, context::AbstractString)
    all(key -> key isa Symbol, keys(data)) || throw(ArgumentError(
        "$context must use symbol keys, as produced by the JSON reader",
    ))
    return nothing
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
    ismissing(node.location) || node.location == loc.id || throw(ArgumentError(
        "Node `$(node.id)` already belongs to location `$(node.location)`; cannot assign it to `$(loc.id)`",
    ))
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
        validate_location_input_keys(entry, context)
        data = Dict{Symbol,Any}(entry)
    else
        throw(ArgumentError("$context must be an object with an `id` field or a location name string"))
    end
    return LocationInput(;
        id = haskey(data, :id) ? data[:id] : throw(ArgumentError("$context requires an `id` field")),
        constraints = get(data, :constraints, Dict{Symbol,Any}()),
        commodities = get(data, :commodities, Dict()),
    )
end

function load_locations!(system::AbstractSystem, rel_or_abs_path::String, data::AbstractVector)
    system.locations = Union{Node,Location}[]
    for (index, entry) in enumerate(data)
        input = parse_location_input(entry, index)
        location = Location(input, system)
        add!(system, location)
        load_location_nodes!(system, input)
    end
    return nothing
end

function load_location_nodes!(system::AbstractSystem, input::LocationInput)
    for (commodity, details) in input.commodities
        haskey(system.commodities, commodity) || throw(ArgumentError(
            "Commodity `$commodity` in location `$(input.id)` is not defined in the system",
        ))
        haskey(system.time_data, commodity) || throw(ArgumentError(
            "Time data for commodity `$commodity` in location `$(input.id)` is not defined",
        ))
        node_data = deepcopy(details)
        if haskey(node_data, :location)
            node_data[:location] isa Union{Symbol,AbstractString} && Symbol(node_data[:location]) == Symbol(input.id) ||
                throw(ArgumentError("Commodity `$commodity` in location `$(input.id)` has a conflicting `location` field"))
        end
        if haskey(node_data, :type)
            node_data[:type] isa Union{Symbol,AbstractString} && Symbol(node_data[:type]) == commodity ||
                throw(ArgumentError("Commodity `$commodity` in location `$(input.id)` has a conflicting `type` field"))
        end
        node_data[:location] = input.id
        node_data[:id] = get(node_data, :id, "$(input.id)_$commodity")
        node_data[:id] isa Union{Symbol,AbstractString} && !isempty(strip(string(node_data[:id]))) ||
            throw(ArgumentError("Node ID for commodity `$commodity` in location `$(input.id)` must be a nonempty string or symbol"))
        load!(system, Dict{Symbol,Any}(:type => commodity, :instance_data => node_data))
    end
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
