###### ###### ###### ###### ###### ######
# Function to load time series data
###### ###### ###### ###### ###### ######

function load_time_series_data!(system::System, data::AbstractDict{Symbol,Any})
    # get list of paths to time series data
    time_series_paths = get_value_and_keys(data, :timeseries)

    # load each time series data and update the data dictionary
    for (value, keys) in time_series_paths
        file_path = rel_or_abs_path(value[:path], system.data_dirpath)
        time_series = load_time_series_data(file_path, value[:header])
        update_data!(data, keys[1:end-1], time_series) # end-1 to exclude the :timeseries key itself and replace it with the actual data
    end

    return nothing
end

function load_time_series_data(
    file_path::AbstractString,
    header::T,
)::Vector{Float64} where {T<:Union{Symbol,String}}
    time_series = load_csv(file_path, select = Symbol(header))
    return time_series[!, header]
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
