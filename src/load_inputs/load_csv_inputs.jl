###### ###### ###### ###### ###### ######
# CSV data handling
###### ###### ###### ###### ###### ######

@doc raw"""
    load_time_series_data(file_path::AbstractString, header::AbstractVector{Symbol})::Dict{Symbol,Any}

    Load time series data from one or more headers in a CSV file and return as a DataFrame.

"""
function load_csv(
    file_path::AbstractString;
    select::S = Symbol[],
    lazy_load::Bool = true,
) where {S<:Union{Symbol,Vector{Symbol}}}
    if isa(select, Symbol)
        select = [select]
    end
    csv_data = read_csv(file_path, select)
    return csv_data
    #TODO check how to use lazy_load with CSV files
end

###### ###### ###### ###### ###### ######
# CSV --> Dict
###### ###### ###### ###### ###### ######

# The general idea is that each row of the CSV
# file is an entry, and each column is a property.
# Each CSV file will be specific to one kind of 
# asset, node, etc.

# Nested properties in a dict, will be denoted by
# the <top_property>--<sub_property> notation.>

function load_csv_inputs(file_path::AbstractString; rel_path::AbstractString=dirname(file_path), lazy_load::Bool = true)::Dict{Symbol, Any}
    @debug("Loading CSV data from $file_path")
    json_data = csv_to_json(file_path)
    # if isempty(json_data)
    #     return Dict{Symbol, Any}(:path => file_path)
    # end
    if !lazy_load
        json_data = eager_load_json_inputs(json_data, rel_path)
        # if isempty(json_data)
        #     return Dict{Symbol, Any}(:path => file_path)
        # end
        json_data = clean_up_keys.(json_data)
    end
    typename = splitext(basename(file_path))[1]
    return Dict{Symbol, Any}(Symbol(typename) => json_data)
end

function validate_csv_data(loaded_csv)::Bool
    headers = loaded_csv.names
    # headers must be at least 2 columns
    if length(headers) < 2
        @debug("CSV file must have at least 2 columns: type and id")
        return false
    end
    # The first column must be "type"
    if headers[1] != :Type
        @debug("The first column of the CSV file must be 'Type'")
        return false
    end
    # The second column must be "id"
    if headers[2] != :id
        @debug("The second column of the CSV file must be 'id'")
        return false
    end
    return true
end

function insert_data(dict::Dict{Symbol, Any}, keys::Vector{Symbol}, data::Any)
    # Create nested dictionaries for each key in the vector
    next_key = keys[1]
    
    if length(keys) == 1
        dict[next_key] = data
        return dict
    end
    
    if !haskey(dict, next_key)
        dict[next_key] = Dict{Symbol, Any}()
    end
    return insert_data(dict[next_key], keys[2:end], data)
end

function csv_to_json(file_path::AbstractString, nesting_str::AbstractString="--")::Vector{Dict{Symbol,Any}}
    data = duckdb_read(file_path)
    if !validate_csv_data(data)
        return Vector{Dict{Symbol,Any}}()
    end

    column_map = Dict{Symbol, Any}()
    for header in data.names
        props = Symbol.(split(string(header), nesting_str))
        column_map[header] = [:instance_data, props...]
    end
    # Take "Type" out of instance_data
    # FIXME: maybe we should move the type into the instance data
    column_map[:Type] = [:type]
    
    all_json_data = Vector{Dict{Symbol, Any}}()
    for row in data
        json_data = Dict{Symbol, Any}()
        for (col_name, dict_address) in column_map
            insert_data(json_data, dict_address, row[col_name])
        end
        Base.push!(all_json_data, json_data)
    end

    return all_json_data
end

Base.@kwdef mutable struct VectorData
    file_path::String = "vector_data.csv"
    headers::Vector{Symbol} = Symbol[]
    data::Vector{Vector{Float64}} = Vector{Vector{Float64}}()
    lengths::Vector{Int} = Int[]
    max_length::Int = 0
end

function add!(vec_data::VectorData, data::Vector{<:Real}, header::Symbol)
    if header in vec_data.headers
        error("Header $header already exists in VectorData $(vec_data.file_path)")
    end
    Base.push!(vec_data.headers, header)
    Base.push!(vec_data.data, data)
    new_length = length(data)
    Base.push!(vec_data.lengths, new_length)
    vec_data.max_length = max(vec_data.max_length, new_length)
    return nothing
end

function fillmissing!(vec_data::VectorData)
    for (idx, vec) in enumerate(vec_data.data)
        vec = [vec; fill(missing, vec_data.max_length - vec_data.lengths[idx])]
    end
    return nothing
end

function new_header(vec_data::VectorData, header::AbstractString)
    if !(header in vec_data.headers)
        return string(header)
    end
    counter = 1
    new_header = string(header, "_", counter)
    while new_header in vec_data.headers
        counter += 1
        new_header = string(header, "_", counter)
    end
    return new_header
end

function new_header(vec_data::VectorData, header::Symbol)
    return new_header(vec_data, string(header))
end

function extract_data!(json_data::AbstractDict{Symbol, <:Any}, row_data::AbstractDict{Symbol, Any}, vec_data::VectorData, prefix::AbstractString="", nesting_str::AbstractString="--")
    for (key, value) in json_data
        if value isa Dict
            new_prefix = prefix * string(key) * nesting_str
            extract_data!(value, row_data, vec_data, new_prefix, nesting_str)
        elseif value isa Vector
            if length(value) == 1
                row_data[Symbol(prefix * string(key))] = value[1]
            else
                header = Symbol(new_header(vec_data, prefix * string(key)))
                add!(vec_data, value, header)
                row_data[header] = Dict{Symbol,Any}(
                    :timeseries => Dict{Symbol,Any}(
                        :path => vec_data.file_path,
                        :header => header,
                    )
                )
            end
        else
            row_data[Symbol(prefix * string(key))] = value
        end
    end
end

Base.@kwdef struct RowData
    asset_data::Dict{Symbol, Vector{OrderedDict{Symbol, Any}}} = Dict{Symbol, Vector{OrderedDict{Symbol, Any}}}()
    assets::Set{Symbol} = Set{Symbol}()
    headers::Dict{Symbol, Set{Symbol}} = Dict{Symbol, Set{Symbol}}()
end

function merge!(row_data::RowData, new_row_data::RowData)
    for (asset_type, data) in new_row_data.asset_data
        if haskey(row_data.asset_data, asset_type)
            append!(row_data.asset_data[asset_type], data)
            union!(row_data.headers[asset_type], new_row_data.headers[asset_type])
        else
            row_data.asset_data[asset_type] = data
            row_data.headers[asset_type] = new_row_data.headers[asset_type]
            Base.push!(row_data.assets, asset_type)
        end
    end
    return nothing
end

function push!(row_data::RowData, asset_type::Symbol, data::OrderedDict{Symbol, Any})
    if !haskey(row_data.asset_data, asset_type)
        row_data.asset_data[asset_type] = Vector{OrderedDict{Symbol, Any}}()
        row_data.headers[asset_type] = Set{Symbol}()
        Base.push!(row_data.assets, asset_type)
    end 
    Base.push!(row_data.asset_data[asset_type], data)
    union!(row_data.headers[asset_type], keys(data))
    return nothing
end

function assets(row_data::RowData)
    return row_data.assets
end

function fillmissing!(row_data::RowData)
    for (asset_type, data) in row_data.asset_data
        for row in data
            for header in row_data.headers[asset_type]
                if !haskey(row, header)
                    row[header] = missing
                end
            end
        end
    end
    return nothing
end

"""
    json_to_csv(json_data::AbstractDict{Symbol, Any}, vec_data::VectorData=VectorData(), nesting_str::AbstractString="--")

    Convert a JSON object to a CSV file. The Dict should contain a single 
    asset described by :type, :instance_data, and possibly :global_data fields.

    # Arguments
    - `json_data`: The JSON object to convert.
    - `vec_data`: The VectorData object to store the timeseries or other vector data in.
    - `nesting_str`: The string used to denote nested properties.

    # Returns
    - A vector of OrderedDicts containing the data for each instance
"""
function json_to_csv(json_data::AbstractDict{Symbol, Any}, row_data::RowData=RowData(), vec_data::VectorData=VectorData(), nesting_str::AbstractString="--")
    if !haskey(json_data, :type)
        @debug("Missing :type key in $(json_data)")
        for (key, value) in json_data
            if key in [:global_data, :instance_data]
                error("Invalid JSON data format: $key should not be present without a :type key")
            end
            merge!(row_data, json_to_csv(value, RowData(), vec_data, nesting_str))
        end
        return row_data
    end

    asset_type = Symbol(json_data[:type])
        
    global_row_data = OrderedDict{Symbol, Any}()
    if haskey(json_data, :global_data)
        extract_data!(json_data[:global_data], global_row_data, vec_data, "", nesting_str)
    end

    if !haskey(json_data, :instance_data)
        #TODO: We need to decide if we want to keep this
        # behaviour or return an error
        return RowData(OrderedDict(asset_type => global_row_data))
    end

    # Assuming haskey(json_data, :instance_data) = true
    # As currently formatted, :Type and :id key must be
    # the first and second columns in row_data
    # all_row_data = Dict{Symbol, Vector{OrderedDict{Symbol, Any}}}(
    #     asset_type => Vector{OrderedDict{Symbol, Any}}()
    # )
    for instance_data in json_data[:instance_data]
        asset_row_data = OrderedDict{Symbol, Any}(
            :Type => string(asset_type),
            :id => instance_data[:id]
        )
        delete!(instance_data, :id)
        Base.merge!(asset_row_data, deepcopy(global_row_data))
        extract_data!(instance_data, asset_row_data, vec_data, "", nesting_str)
        push!(row_data, asset_type, asset_row_data)
    end

    if vec_data.max_length > 0
        fillmissing!(vec_data)
        write_csv(vec_name.file_path, DataFrame(vec_data.data, vec_data.headers))
    end
        
    return row_data
end

function json_to_csv(json_data::Vector{Dict{Symbol, Any}}, row_data::RowData=RowData(), vec_data::VectorData=VectorData(), nesting_str::AbstractString="--")
    for json in json_data
        merge!(row_data, json_to_csv(json, RowData(), vec_data, nesting_str))
    end
    return row_data
end

function file_suffix(file_path::AbstractString, suffix_options)
    for suffix in suffix_options
        if endswith(file_path, suffix)
            return suffix
        end
    end
    @debug ("File $file_path does not have a valid suffix in $suffix_options")
    return ""
end

function convert_json_to_csv(file_path::AbstractString, rel_path::AbstractString=dirname(file_path), lazy_load::Bool=true, compress::Bool=false)
    json_data = load_json_inputs(file_path; rel_path=rel_path, lazy_load=lazy_load)
    csv_data = json_to_csv(json_data)
    fillmissing!(csv_data)

    dataframes = Vector{DataFrame}()
    for (asset_type, asset_data) in csv_data.asset_data
        file_root = splitext(basename(file_path))[1]
        csv_file_path = joinpath(dirname(file_path))
        csv_file_path = find_available_filepath(csv_file_path, "$file_root.csv")
        df = DataFrame(asset_data)
        Base.push!(dataframes, df)
        write_csv(csv_file_path, df, compress)
    end

    return dataframes
end

function convert_jsons_to_csv(dir_path::AbstractString, rel_path::AbstractString=dir_path, lazy_load::Bool=false, compress::Bool=false)
    json_files = readdir(dir_path)
    json_files = filter(x -> any(endswith(x, s) for s in @JSON_EXT), json_files)

    dataframes = Vector{DataFrame}()
    for json_file in json_files
        json_file_path = joinpath(dir_path, json_file)
        dfs = convert_json_to_csv(json_file_path, rel_path, lazy_load, compress)
        append!(dataframes, dfs)
    end

    return dataframes
end

