###### ###### ###### ###### ###### ######
# Function to write the system data to a JSON file
###### ###### ###### ###### ###### ######
"""
    write_to_json(system::System, file_path::AbstractString=""; compress::Bool=true)
    write_to_json(case::Case, file_path::AbstractString=""; compress::Bool=true)

Serialize a `System` or `Case` object to a JSON file.

# Arguments
- `system` or `case`: The object to serialize.
- `file_path`: Path to the output file. Defaults to `output_system_data.json` in the current directory.
  If `compress=true` and the path does not end in `.gz`, the `.gz` extension is appended automatically.

# Keyword Arguments
- `compress::Bool=true`: Whether to gzip-compress the output file.

# Notes
- When serializing a `Case`, the output contains two top-level keys: `:case` (a vector of
  per-period system data) and `:settings` (the case settings).
- Constraint dual values are included in the output when available.
"""
function write_to_json(system::System, file_path::AbstractString=""; compress::Bool=true)::Nothing
    system_data = prepare_to_json(system)
    file_path = file_path == "" ? joinpath(pwd(), "output_system_data.json") : file_path
    @info("Writing system data to JSON file at: ", file_path)
    write_json(file_path, system_data, compress)
    return nothing
end

function write_to_json(case::Case, file_path::AbstractString=""; compress::Bool=true)::Nothing
    case_data = Dict{Symbol, Any}(
        :case => [prepare_to_json(system) for system in case.systems],
        :settings => prepare_to_json(case.settings)
    )
    file_path = file_path == "" ? joinpath(pwd(), "output_system_data.json") : file_path
    @info("Writing system data to JSON file at: ", file_path)
    write_json(file_path, case_data, compress)
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
            data = prepare_commodities_to_json(system.commodities)
        elseif field == :locations  #TODO: Remove this once we have locations
            field = :nodes
        elseif ismissing(data) || field == :input_data
            continue    # Skip missing data
        end
        system_data[field] = prepare_to_json(data)
    end

    system_data[:locations] = Dict{Symbol, Any}(
        :path => "system/locations.json"
    )
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
        :type => typesymbol(commodity_type(node)),
        :instance_data => prepare_to_json(node, fields_to_exclude),
    )
end

function prepare_to_json(asset::AbstractAsset)
    asset_data = Dict{Symbol,Any}(
        :type => Base.typename(typeof(asset)).name,  # e.g., this will give just "ThermalPower" instead of "ThermalPower{NaturalGas}"
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
            asset_data[:instance_data][:edges][f][:commodity] = typesymbol(commodity_type(data))
            if isa(data, EdgeWithUC)
                asset_data[:instance_data][:edges][f][:uc] = true
            end
        elseif isa(data, Transformation)
            asset_data[:instance_data][:transforms] = prepare_to_json(data)
        elseif isa(data, AbstractStorage)
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
function prepare_to_json(storage::AbstractStorage)
    fields_to_exclude = [:operation_expr, :discharge_edge, :charge_edge]
    storage_data = prepare_to_json(storage, fields_to_exclude)
    storage_data[:commodity] = typesymbol(commodity_type(storage))
    return storage_data
end

function prepare_to_json(location::Location)
    return Dict{Symbol, Any}()
end

# This function prepares MacroObject objects (e.g., Storage, Transformation, Nodes, Edges)
function prepare_to_json(object::MacroObject, fields_to_exclude::Vector{Symbol}=Symbol[])
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
    dict = Dict{Symbol,Any}()
    for constraint in constraints
        con_ref = constraint_ref(constraint)
        if ismissing(con_ref)
            dict[Symbol(typeof(constraint))] = true
            continue
        end            
        dual_value = dual.(con_ref)
        if ismissing(dual_value)
            dict[Symbol(typeof(constraint))] = true
        else
            dict[Symbol(typeof(constraint))] = prepare_to_json(dual_value)
        end
    end
    return dict
end

function prepare_to_json(constraints::Dict{DataType, Union{JuMP.Containers.DenseAxisArray, JuMP.Containers.SparseAxisArray, Array, ConstraintRef}})
    return Dict(Symbol(k) => true for k in keys(constraints))
end

function prepare_to_json(data::Dict)
    return Dict(k => prepare_to_json(v) for (k, v) in data)
end

# If DataTypes are used as keys in a dictionary, we convert them to symbols
function prepare_to_json(data::Dict{DataType,Any})
    return Dict(Symbol(k) => v for (k, v) in data)
end

function prepare_to_json(data::OrderedDict{Symbol,SupplySegment})
    return OrderedDict{Symbol,OrderedDict{Symbol,Vector{Any}}}(
        segment_name => prepare_to_json(segment) for (segment_name, segment) in data
    )
end

function prepare_to_json(segment::SupplySegment)
    return OrderedDict{Symbol,Any}(
        :price => prepare_to_json(segment.price),
        :min => prepare_to_json(segment.min),
        :max => prepare_to_json(segment.max),
    )
end

function prepare_to_json(data::NamedTuple)
    return Dict(Symbol(k) => prepare_to_json(v) for (k, v) in pairs(data))
end

# TimeData field of MacroObjects are written as the commodity type
function prepare_to_json(timedata::TimeData)
    return typesymbol(commodity_type(timedata))
end

function prepare_to_json(data::Dict{Symbol,TimeData})
    time_data = Dict(
        :NumberOfSubperiods => 0,
        :HoursPerTimeStep => Dict{Symbol,Int}(),
        :HoursPerSubperiod => Dict{Symbol,Int}(),
        :TotalHoursModeled => 0.0
    )
    for (k, v) in data
        time_data[:NumberOfSubperiods] = length(v.subperiod_indices)
        time_data[:HoursPerTimeStep][k] = v.hours_per_timestep
        time_data[:HoursPerSubperiod][k] = length(v.subperiods[1]) # TODO: Check this
        time_data[:TotalHoursModeled] = v.total_hours_modeled
    end
    
    # Make subperiod map
    (comm, comm_time_data) = first(data)
    rep_period_map = Dict(p => idx for (idx,p) in enumerate(comm_time_data.subperiod_indices))
    period_map = DataFrame([
       Dict{Symbol,Int64}(:Period_Index => p, :Rep_Period => comm_time_data.subperiod_map[p], :Rep_Period_Index => rep_period_map[comm_time_data.subperiod_map[p]]) for p in 1:time_data[:NumberOfSubperiods]
    ])
    # Using JSONTables and JSON3 to automatically handle future formatting changes
    time_data[:SubPeriodMap] = copy(JSON3.read(objecttable(period_map)))
    return time_data
end

function prepare_to_json(data::AbstractSolutionAlgorithm)
    return string(nameof(typeof(data)))
end

function prepare_to_json(data::Missing)
    return ""
end

function prepare_to_json(data::AbstractJuMPScalar)
    return value(data)
end

function prepare_to_json(data::JuMP.Containers.DenseAxisArray{<:AbstractJuMPScalar})
    return value.(data).data
end

# DenseAxisArray{Float64} (e.g. from dual.(con_ref)) — extract the plain Array first
# to avoid StepRange axis issues when iterating or collecting
function prepare_to_json(data::JuMP.Containers.DenseAxisArray)
    return prepare_to_json(data.data)
end

function prepare_to_json(data::AbstractArray{<:AbstractJuMPScalar})
    return value.(data)
end

function prepare_to_json(data::AbstractVector)
    return [prepare_to_json(v) for v in data]
end

# In general, for all attributes (Floats, Strings, etc), `prepare_to_json` simply returns the data as it is
function prepare_to_json(data)
    if data == Inf 
        return "Inf"
    elseif data == -Inf
        return "-Inf"
    elseif data == NaN
        return "NaN"
    end
    return data
end

###### ###### ###### ###### ###### ######
# Specialized function to write Commodities
###### ###### ###### ###### ###### ######
# TODO: We should merge this into prepare_to_json using a Type for this kind of data
function prepare_commodities_to_json(commodities::Dict{Symbol, DataType})
    # We'll get a dict{Symbol, DataType} where the key is the commodity name and value is the commodity type
    # We want to check if the parent module of the commodity type is MacroEnergy or UserAdditions
    # If it's the latter, we'll create the correct input format designating it's parent commodity
    commodity_defs = Union{Symbol, Dict{Symbol, Any}}
    commodity_data = Vector{commodity_defs}()
    commodity_tree = Dict{Symbol, Vector{commodity_defs}}(
        :Commodity => Vector{Dict{Symbol, Any}}()
    )

    for (commodity_id, commodity) in commodities
        super = supertype(commodity)
        # Top-level commodities, from MacroEnergy or UserAdditions
        if super == MacroEnergy.Commodity
            push!(commodity_tree[:Commodity], commodity_id)
            continue
        end
        # Sub-commodities from UserAdditions
        super_id = typesymbol(super)
        if !haskey(commodity_tree, super_id)
            commodity_tree[super_id] = Vector{commodity_defs}()
        end
        push!(commodity_tree[super_id], Dict{Symbol, Any}(
            :name => commodity_id,
            :acts_like => typesymbol(super),
        ))
    end

    # We now iterate through the commodity tree, starting from top-level commodities
    for commodity in commodity_tree[:Commodity]
        push!(commodity_data, commodity)
        if haskey(commodity_tree, commodity)
            expand_commodity_tree(commodity_tree, commodity, commodity_data)
        end
    end
    
    return commodity_data
end

function expand_commodity_tree(commodity_tree, commodity_id::Symbol, commodity_data::Vector)
    for subcommodity in commodity_tree[commodity_id]
        push!(commodity_data, subcommodity)
        subcommodity_id = subcommodity[:name]
        if haskey(commodity_tree, subcommodity_id)
            expand_commodity_tree(commodity_tree, subcommodity_id, commodity_data)
        end
    end
    return nothing
end