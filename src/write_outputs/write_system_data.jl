###### ###### ###### ###### ###### ######
# Function to print the system data
###### ###### ###### ###### ###### ######
# TODO: For now, I commented out the function that prints the system data to a JSON file
#       because we first need to fix the issue with in-place modification of the edge ids.
#       We can uncomment it once we have a solution for that.
# function print_to_json(system::System, file_path::AbstractString="")::Nothing
#     # Note: right now System does not have a node field, so we're using locations
#     system_data = prepare_to_json(system)
#     print_to_json(system_data, file_path)
#     return nothing
# end
function write_system_data(
    system_data::AbstractDict{Symbol,Any},
    file_path::AbstractString = "",
)::Nothing
    if file_path == ""
        file_path = joinpath(pwd(), "printed_system_data.json")
    end
    write_json(file_path, system_data)
    return nothing
end

###### ###### ###### ###### ###### ######
# Function to prepare the system data for being printed to JSON
###### ###### ###### ###### ###### ######
# This is a recursive function that goes through the system data and prepares it for being printed to a JSON file
function prepare_to_json(system::System)
    system_data = Dict{Symbol,Any}()
    for field in Base.fieldnames(typeof(system))    # Loop through the fields of the System object
        data = getfield(system, field)
        if field == :commodities    # commodites are stored as a vector of strings not a dict in the JSON file
            data = keys(data)
        elseif field == :locations  #TODO: Remove this once we have locations
            field = :nodes
        end
        system_data[field] = prepare_to_json(data)
    end
    return system_data
end

# Loops through the vector of nodes and assets and prepares them for being printed to a JSON file
function prepare_to_json(data::AbstractArray{T}) where {T<:MacroObject}
    processed_data = Vector{Dict{Symbol,Any}}(undef, length(data))
    for idx in eachindex(data)
        processed_data[idx] = prepare_to_json(data[idx])
    end
    return processed_data
end

# This function prepares Node objects for being printed to a JSON file
function prepare_to_json(node::Node)
    fields_to_exclude = [:policy_budgeting_vars, :policy_slack_vars]
    return Dict{Symbol,Any}(
        :type => Symbol(commodity_type(node)),
        :instance_data => prepare_to_json(node, fields_to_exclude),
    )
end

function prepare_to_json(asset::AbstractAsset)
    asset_data = Dict{Symbol,Any}(
        :type => typeof(asset),
        :instance_data => Dict{Symbol,Any}(
            :edges => Dict{Symbol,Any}(),
            :transforms => Dict{Symbol,Any}(),
            :storage => Dict{Symbol,Any}(),
        ),
    )

    for f in Base.fieldnames(typeof(asset))
        data = getfield(asset, f)
        if isa(data, AbstractEdge)
            asset_data[:instance_data][:edges][f] = prepare_to_json(data)
        elseif isa(data, Transformation)
            asset_data[:instance_data][:transforms] = prepare_to_json(data)
        elseif isa(data, Storage)
            asset_data[:instance_data][:storage] = prepare_to_json(data)
        else    # e.g., AssetId
            asset_data[:instance_data][f] = data
        end
    end
    return asset_data
end

# This function prepares AbstactVertex objects (e.g., transformations) for 
function prepare_to_json(vertex::AbstractVertex)
    fields_to_exclude = [:operation_expr]
    return prepare_to_json(vertex, fields_to_exclude)
end

# We override the default prepare_to_json function for storage objects to exclude discharge_edge and charge_edge
function prepare_to_json(storage::Storage)
    fields_to_exclude = [:operation_expr, :discharge_edge, :charge_edge]
    storage_data = prepare_to_json(storage, fields_to_exclude)
    storage_data[:commodity] = commodity_type(storage)
    return storage_data
end

# This function prepares MacroObject objects (e.g., Storage, Transformation, Nodes, Edges). Note: edges have their own function
function prepare_to_json(object::MacroObject, fields_to_exclude::Vector{Symbol} = Symbol[])
    object_data = Dict{Symbol,Any}()
    for field in filter(x -> !in(x, fields_to_exclude), Base.fieldnames(typeof(object)))
        data = getfield(object, field)
        # Skip empty fields
        if (isa(data, AbstractDict) || isa(data, AbstractVector)) && isempty(data)
            continue
        end
        # If the field is a node or vertex, we need to write the id not the object
        if isa(data, AbstractVertex)
            object_data[field] = id(data)
        else
            object_data[field] = prepare_to_json(data)
        end
    end
    return object_data
end

# Constraints are written as a dictionary of constraint names and true/false values
function prepare_to_json(constraints::Vector{AbstractTypeConstraint})
    return Dict(Symbol(typeof(constraint)) => true for constraint in constraints)
end

# If DataTypes are used as keys in a dictionary, we convert them to symbols
function prepare_to_json(data::Dict{DataType,Any})
    return Dict(Symbol(k) => v for (k, v) in data)
end

# TimeData field of MacroObjects are written as the commodity type
function prepare_to_json(timedata::TimeData)
    return Symbol(commodity_type(timedata))
end

function prepare_to_json(data::Dict{Symbol,TimeData})
    time_data = Dict(
        :PeriodLength => 0,
        :HoursPerTimeStep => Dict{Symbol,Int}(),
        :HoursPerSubperiod => Dict{Symbol,Int}(),
    )
    for (k, v) in data
        time_data[:PeriodLength] = v.time_interval[end]
        time_data[:HoursPerTimeStep][k] = v.hours_per_timestep
        time_data[:HoursPerSubperiod][k] = v.time_interval[end] # TODO: Implement this
    end

    return time_data
end

# In general, for all attributes (Floats, Strings, etc), `prepare_to_json` simply returns the data as it is
function prepare_to_json(data)
    data == Inf && return "Inf"
    return data
end
