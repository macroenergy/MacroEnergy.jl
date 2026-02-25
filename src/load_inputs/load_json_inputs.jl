###### ###### ###### ###### ###### ######
# JSON data handling
###### ###### ###### ###### ###### ######

@doc raw"""
    load_json_inputs(file_path::AbstractString; rel_path::AbstractString=dirname(file_path), lazy_load::Bool = true)::Dict{Symbol,Any}

    Load JSON data from a file and return a Dict{Symbol,Any} object. The data can all be included in the 
    specified JSON file or distributed across multiple files and directories, with each source specified
    using "path" or "timeseries" keys.\n 
    The `rel_path` argument is used to specify the path relative to which the file paths of this distributed
    data should be resolved.\n
    If `lazy_load` is set to `true`, then only the top-level data in the specified JSON file will be loaded. 
    If `lazy_load` is set to `false`, then the distrinuted data will be loaded recursively into the 
    appropriate data structures.

"""
function load_json_inputs(file_path::AbstractString; rel_path::AbstractString=dirname(file_path), lazy_load::Bool = true)::Dict{Symbol,Any}
    @debug("Loading JSON data from $file_path")
    json_data = copy(read_json(file_path))
    # if isempty(json_data)
    #     return Dict{Symbol, Any}(:path => file_path)
    # end
    if !lazy_load || GLOBAL_TDR_FLAG[] == 1
        json_data = eager_load_json_inputs(json_data, rel_path)
        # if isempty(json_data)
        #     return Dict{Symbol, Any}(:path => file_path)
        # end
        json_data = clean_up_keys(json_data)
    end
    return json_data
end

@doc raw"""
    eager_load_json_inputs(json_data::AbstractDict{Symbol, Any}, rel_path::AbstractString)::AbstractDict{Symbol, Any}

    Recursively loads data from sources specified in an input Dict{Symbol,Any} and returns a new 
    Dict{Symbol,Any} object with the data inserted.

"""
function eager_load_json_inputs(json_data::AbstractDict{Symbol, Any}, rel_path::AbstractString)
        # For now we'll spell out the reserved keys explicitly
        if haskey(json_data, :path)
            return fetch_data(json_data[:path], json_data, rel_path, false)
        elseif haskey(json_data, :timeseries)
            ts = json_data[:timeseries]
        
            if GLOBAL_TDR_FLAG[] == 1
                # When TimeDomainReduction=1, TDR_path must exist
                if !haskey(ts, :TDR_path)
                    error("TimeDomainReduction=1 but TDR_path is missing for timeseries $(ts). Please update JSON.")
                end
        
                # TDR = 1: Use TDR_path for timeseries in system/TDR_results folder
                file_path = rel_or_abs_path(ts[:TDR_path], rel_path)
            else
                # TDR = 0: Use path for timeseries in system folder
                file_path = rel_or_abs_path(ts[:path], rel_path)
            end
        
            # Now load the selected time series
            return load_time_series_data(file_path, ts[:header])
        end
        
        for (key, value) in json_data
            if hasmethod(eager_load_json_inputs, (typeof(value), typeof(rel_path)))
                json_data[key] = eager_load_json_inputs(value, rel_path)
            end
        end
    return json_data
end

@doc raw"""
    eager_load_json_inputs(json_data::AbstractVector{<:AbstractDict{Symbol,Any}}, rel_path::AbstractString)::AbstractVector{<:AbstractDict{Symbol,Any}}

    Recursively loads data from sources specified in several input Dict{Symbol,Any}, stored as a Vector, 
    and returns a new Vector{Dict{Symbol,Any}} object with the data inserted.

"""
function eager_load_json_inputs(json_data::AbstractVector{<:AbstractDict{Symbol,Any}}, rel_path::AbstractString)
    for idx in eachindex(json_data)
        json_data[idx] = eager_load_json_inputs(json_data[idx], rel_path)
    end
    return json_data
end

@doc raw"""
    clean_up_keys(dict::AbstractDict{Symbol,Any})::AbstractDict{Symbol,Any}

    Clean up a Dict{Symbol,Any} object by copying values from keys that match the key name. 

"""
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

@doc raw"""
    fetch_data(path::AbstractString, dict::AbstractDict{Symbol, Any}, root_path::AbstractString, lazy_load::Bool = true)::Any

    Fetch data from a JSON file or directory and return it as a Dict{Symbol,Any} object.

"""
function fetch_data(path::AbstractString, dict::AbstractDict{Symbol, Any}, root_path::AbstractString, lazy_load::Bool = true)
    @debug("FETCHING DATA FROM: $path")
    path = rel_or_abs_path(path, root_path)
    
    if isfile(path) && isjson(path)
        return load_inputs(path; rel_path=root_path, lazy_load=lazy_load)
    end

    if isfile(path) && iscsv(path)
        temp = load_csv_inputs(path)
        if !all(isempty.(values(temp)))
            return temp
        end
        return read_csv(path)
    end

    # In the future we can include a CSV -> Dict conversion
    # if isfile(path) && iscsv(path)
        # return load_time_series_data(path, dict[:header])
    # end
    if isdir(path)
        files = get_json_files(path)
        append!(files, get_csv_files(path))
        if length(files) > 1
            dir_data = Vector{Dict{Symbol,Any}}()
            for file in files
                @debug("Loading data from $file")
                temp = load_inputs(joinpath(path, file); rel_path=root_path, lazy_load=lazy_load)
                if !isempty(temp)
                    push!(dir_data, temp)
                end
            end
            return dir_data
        end
    end
    @warn "Could not find: \"$(path)\", full path: $(abspath(path))"
    return path
end