###### ###### ###### ###### ###### ######
# Function to load time series data
###### ###### ###### ###### ###### ######

function load_time_series_data!(data::AbstractDict{Symbol,Any}, data_dirpath::AbstractString, timeseries::Dict{String, DataFrame})::Nothing
    # Retrieve list of paths to time series data
    timeseries_paths = get_value_and_keys(data, :timeseries)
    # Process each time series data path
    for (value, keys) in timeseries_paths
        file_path = rel_or_abs_path(value[:path], data_dirpath)
        header = value[:header]
        update_data!(data, keys[1:end-1], get_time_series(file_path, header, timeseries)) # end-1 to exclude the :timeseries key itself and replace it with the actual data
    end
    return nothing
end

function get_time_series(file_path::AbstractString, header::T, timeseries::Dict{String, DataFrame})::Vector{Float64} where {T<:Union{Symbol, String}}
    # Check if the file_path data is already loaded in ts_dict
    if haskey(timeseries, file_path)
        # Return the requested time series column
        @debug "Time series data already loaded for $file_path"
        return timeseries[file_path][!, header]
    else
        # Load the CSV data and store in dictionary
        time_series_df = load_csv(file_path)
        timeseries[file_path] = time_series_df  # cache the data for future use
        return time_series_df[!, header]
    end
end

"""
    get_value_and_keys(dict::AbstractDict, target_key::Symbol, keys=Symbol[])

Recursively searches for a target key in a dictionary and returns a list of 
tuples containing the value associated with the target key and the keys leading 
to it.
This function is used to replace the path to a timeseries file with the actual
vector of data.

# Arguments
- `dict::AbstractDict`: The (nested) dictionary to search in.
- `target_key::Symbol`: The key to search for.
- `keys=Symbol[]`: (optional) The keys leading to the current dictionary.

# Returns
- `value_keys`: A list of tuples, where each tuple contains 
                - the value associated with the target key
                - the keys leading to it in the nested dictionary.

# Examples
```julia
dict = Dict(:a => Dict(:b => 1, :c => Dict(:b => 2)))
get_value_and_keys(dict, :b) # returns [(1, [:a, :b]), (2, [:a, :c, :b])]
```
Where the first element of the tuple is the value of the key :b and the second 
element is the list of keys to reach that value.
"""
function get_value_and_keys(dict::AbstractDict, target_key::Symbol, keys = Symbol[])
    value_keys = []

    if haskey(dict, target_key)
        push!(value_keys, (dict[target_key], [keys; target_key]))
    end

    for (key, value) in dict
        if isa(value, AbstractDict)
            result = get_value_and_keys(value, target_key, [keys; key])
            append!(value_keys, result)
        end
    end

    return value_keys
end

# This function is used to get the value of a key in a nested dictionary.
"""
    get_value(dict::AbstractDict, keys::Vector{Symbol})

Get the value from a dictionary based on a sequence of keys.

# Arguments
- `dict::AbstractDict`: The dictionary from which to retrieve the value.
- `keys::Vector{Symbol}`: The sequence of keys to traverse the dictionary.

# Returns
- The value retrieved from the dictionary based on the given keys.

# Examples
```julia
dict = Dict(:a => Dict(:b => 1, :c => Dict(:b => 2)))
get_value(dict, [:a, :b]) # returns 1
get_value(dict, [:a, :c, :b]) # returns 2
```
"""
function get_value(dict::AbstractDict, keys::Vector{Symbol})
    value = dict
    for key in keys
        value = value[key]
    end
    return value
end

"""
    set_value(dict::AbstractDict, keys::Vector{Symbol}, new_value)

Set the value of a nested dictionary given a list of keys.

# Arguments
- `dict::AbstractDict`: The dictionary to modify.
- `keys::Vector{Symbol}`: A list of keys representing the path to the value to 
be modified.
- `new_value`: The new value to set.

# Examples
```julia
dict = Dict(:a => Dict(:b => 1, :c => Dict(:b => 2)))
set_value(dict, [:a, :b], 3)
get_value(dict, [:a, :b]) # returns 3
```
"""
function set_value(dict::AbstractDict, keys::Vector{Symbol}, new_value)
    value = dict
    for key in keys[1:end-1]
        value = value[key]
    end
    value[keys[end]] = new_value
end

function update_data!(data::AbstractDict{Symbol,Any}, keys::Vector{Symbol}, new_value)
    set_value(data, keys, new_value)
end
