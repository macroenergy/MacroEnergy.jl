###### ###### ###### ###### ###### ######
# Functions to handle loading MacroEnergy object data
###### ###### ###### ###### ###### ######

# Load data from a JSON file into a System
function load!(system::System, file_path::AbstractString)::Nothing
    file_path = rel_or_abs_path(file_path, system.data_dirpath)
    if isfile(file_path)
        load!(system, load_json(file_path))
    elseif isdir(file_path)
        for file in get_json_files(file_path)
            load!(system, joinpath(file_path, file))
        end
    end
    return nothing
end

# Load a single instance of an asset, location, etc. into a System
function load!(system::System, data::AbstractDict{Symbol,Any})::Nothing
    if data_is_system_data(data)
        # println("Loading system data")
        load_system_data!(system, data)

        # Check that data has only :type and :instance_data fields
    elseif data_is_single_instance(data)
        data_type = check_and_convert_type(data)
        add!(system, make(data_type, data[:instance_data], system))

    elseif data_has_global_data(data)
        # println("Expanding global data")
        load!(system, expand_instances(system.data_dirpath, data))

    elseif data_is_filepath(data)
        # println("Loading data from file")
        load!(system, data[:path])

    else
        for (key, value) in data
            load!(system, value)
        end

    end

    return nothing
end

# Load a vector of instances of assets, locations, etc. into a System
function load!(system::System, data::AbstractVector{<:AbstractDict{Symbol,Any}})::Nothing
    for instance in data
        load!(system, instance)
    end
    return nothing
end

recursive_merge(x::AbstractDict...) = merge(recursive_merge, x...)
recursive_merge(x::AbstractVector...) = cat(x...; dims = 1)
recursive_merge(x...) = x[end]

function expand_instances(data_dirpath::AbstractString, data::AbstractDict{Symbol,Any})
    instances = Vector{Dict{Symbol,Any}}()
    timeseries = Dict{String, DataFrame}()
    type = data[:type]
    global_data = data[:global_data]
    for (instance_idx, instance_data) in enumerate(data[:instance_data])
        instance_data = recursive_merge(global_data, instance_data)
        # haskey(instance_data, :id) ? instance_id = Symbol(instance_data[:id]) : instance_id = default_asset_name(instance_idx, a_name)
        # instance_data[:id], _ = make_asset_id(instance_id, asset_data)
        # asset_data[instance_data[:id]] = make_asset(a_type, instance_data, time_data, nodes)
        load_time_series_data!(instance_data, data_dirpath, timeseries) # substritute ts file paths with actual vectors of data
        push!(instances, Dict{Symbol,Any}(:type => type, :instance_data => instance_data))
    end
    return instances
end

###### ###### ###### ###### ###### ######
# Checks on the kind of data
###### ###### ###### ###### ###### ######

function check_and_convert_type(data::AbstractDict{Symbol,Any}, m::Module = Macro)
    if !haskey(data, :type)
        throw(ArgumentError("Instance data does not have a :type field"))
    end
    type = Symbol(data[:type])
    validate_type_attribute(type, m)
    return getfield(m, type)
end

function data_is_single_instance(data::AbstractDict{Symbol,Any})::Bool
    # Check that data has only :type and :instance_data fields
    # We could also check the types of the fields
    entries = collect(keys(data))
    if length(entries) == 2 && issetequal(entries, [:type, :instance_data])
        return true
    else
        return false
    end
end

function data_has_global_data(data::AbstractDict{Symbol,Any})::Bool
    # Check that data has only :type, :instance_data, :global_data fields
    entries = collect(keys(data))
    if length(entries) == 3 && issetequal(entries, [:type, :instance_data, :global_data])
        return true
    else
        return false
    end
end

function data_is_filepath(data::AbstractDict{Symbol,Any})::Bool
    entries = collect(keys(data))
    if length(entries) == 1 && issetequal(entries, [:path])
        return true
    else
        return false
    end
end

function data_is_system_data(data::AbstractDict{Symbol,Any})::Bool
    # Check if it contains any special fields
    entries = collect(keys(data))
    special_keys = [:settings]
    for key in special_keys
        if key in entries
            return true
        end
    end
    return false
end

###### ###### ###### ###### ###### ######
# JSON data handling
###### ###### ###### ###### ###### ######

function load_json(file_path::AbstractString; lazy_load::Bool = true)::Dict{Symbol,Any}
    @info("Loading JSON data from $file_path")
    json_data = read_json(file_path)
    if !lazy_load
        # Recursively check if any of the fields are paths to other JSON files
        json_data = load_paths(json_data, :path, dirname(file_path), lazy_load)
        json_data = clean_up_keys(json_data)
    end
    return json_data
end

function load_paths(
    dict::AbstractDict{Symbol,Any},
    path_key::Symbol,
    root_path::AbstractString,
    lazy_load::Bool = true,
)
    if isa(dict, JSON3.Object)
        dict = copy(dict)
    end
    for (key, value) in dict
        if key == path_key
            dict = fetch_data(value, root_path, lazy_load)
        elseif isa(value, AbstractDict{Symbol,Any})
            dict[key] = load_paths(value, path_key, root_path, lazy_load)
        elseif isa(value, AbstractVector{<:AbstractDict{Symbol,Any}})
            for idx in eachindex(value)
                if isa(value[idx], JSON3.Object)
                    value[idx] = copy(value[idx])
                end
                value[idx] = load_paths(value[idx], path_key, root_path, lazy_load)
            end
            dict[key] = value
        end
    end
    return dict
end

function clean_up_keys(dict::AbstractDict{Symbol,Any})
    # If a key and value match, then copy the value to the key
    for (key, value) in dict
        if isa(value, AbstractDict{Symbol,Any}) &&
           length(value) == 1 &&
           first(collect(keys(value))) == key
            dict[key] = value[key]
        elseif isa(value, AbstractVector{<:AbstractDict{Symbol,Any}})
            for idx in eachindex(value)
                if isa(value[idx], AbstractDict{Symbol,Any})
                    value[idx] = clean_up_keys(value[idx])
                end
            end
            dict[key] = value
        end
    end
    return dict
end

function fetch_data(path::AbstractString, root_path::AbstractString, lazy_load::Bool = true)
    # Load data from a JSON file and merge it into the existing data dict
    # overwriting any existing keys
    path = rel_or_abs_path(path, root_path)
    if isfile(path) && isjson(path)
        return load_json(path; lazy_load = lazy_load)
    end
    if isdir(path)
        json_files = get_json_files(path)
        if length(json_files) > 1
            for file in json_files
                return load_json(joinpath(path, file); lazy_load = lazy_load)
            end
        else
            return path
        end
    end
    @warn "Could not find: \"$(path)\", full path: $(abspath(path))"
    return path
end

###### ###### ###### ###### ###### ######
# CSV data handling
###### ###### ###### ###### ###### ######

function load_csv(
    file_path::AbstractString;
    select::S = Symbol[],
    lazy_load::Bool = true,
) where {S<:Union{Symbol,Vector{Symbol}}}
    if isa(select, Symbol)
        select = [select]
    end
    csv_data = read_csv(file_path, select = select)
    return csv_data
    #TODO check how to use lazy_load with CSV files
end