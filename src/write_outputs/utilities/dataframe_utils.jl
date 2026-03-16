"""
DataFrame processing utilities for output data.
"""

"""
    write_dataframe(
        file_path::AbstractString, 
        df::AbstractDataFrame, 
        drop_cols::Vector{<:AbstractString}=String[]
    )

Write a DataFrame to a file in the appropriate format based on file extension.
Supported formats: .csv, .csv.gz, .parquet

# Arguments
- `file_path::AbstractString`: Path where to save the file
- `df::AbstractDataFrame`: DataFrame to write
- `drop_cols::Vector{<:AbstractString}`: Columns to drop from the DataFrame
"""
function write_dataframe(
    file_path::AbstractString,
    df::AbstractDataFrame,
    drop_cols::Vector{<:AbstractString}=String[]
)
    # Extract file extension and check if supported in Macro
    extension = lowercase(splitext(file_path)[2])
    # Create a map (supported_formats => write functions)
    supported_formats = Dict(
        ".csv" => (path, data) -> write_csv(path, data, false),
        ".csv.gz" => (path, data) -> write_csv(path, data, true),
        ".parquet" => write_parquet
    )

    # Validate file extension
    if !any(ext -> endswith(file_path, ext), keys(supported_formats))
        throw(ArgumentError("Unsupported file extension: $extension. Supported formats: $(join(keys(supported_formats), ", "))"))
    end

    # Get the appropriate writer function
    writer = first(writer for (ext, writer) in supported_formats if endswith(file_path, ext))

    # Drop the columns specified by the user
    select!(df, Not(Symbol.(drop_cols)))

    # Write the DataFrame using the appropriate writer function
    writer(file_path, df)

    return nothing
end

# Function to convert a vector of OutputRow objects to a DataFrame for 
# visualization purposes
function convert_to_dataframe(data::Vector{<:Tuple}, header::Vector)
    @assert length(data[1]) == length(header)
    DataFrame(data, header)
end

"""
    reshape_wide(df::DataFrame; variable_col::Symbol=:variable, value_col::Symbol=:value)

Reshape a DataFrame from long to wide format.

# Arguments
- `df::DataFrame`: Input DataFrame
- `variable_col::Symbol`: Column name containing variable names
- `value_col::Symbol`: Column name containing values

# Examples
```julia
df_long = DataFrame(id=[1,1,2,2], variable=[:a,:b,:a,:b], value=[10,30,20,40])
df_wide = reshape_wide(df_long)
```
"""
function reshape_wide(df::DataFrame, variable_col::Symbol=:variable, value_col::Symbol=:value)
    if !all(col -> col ∈ propertynames(df), [variable_col, value_col])
        throw(ArgumentError("DataFrame must contain '$variable_col' and '$value_col' columns for wide format"))
    end
    return unstack(df, variable_col, value_col)
end

"""
    reshape_wide(df::DataFrame, id_cols::Union{Vector{Symbol},Symbol}, variable_col::Symbol, value_col::Symbol)

Reshape a DataFrame from long to wide format.

# Arguments
- `df::DataFrame`: DataFrame in long format to be reshaped
- `id_cols::Union{Vector{Symbol},Symbol}`: Column(s) to use as identifiers
- `variable_col::Symbol`: Column containing variable names that will become new columns
- `value_col::Symbol`: Column containing values that will fill the new columns

# Returns
- `DataFrame`: Reshaped DataFrame in wide format

# Throws
- `ArgumentError`: If required columns are not present in the DataFrame

# Examples
```julia
df_wide = reshape_wide(df, :year, :variable, :value)
```
"""
function reshape_wide(df::DataFrame, id_cols::Union{Vector{Symbol},Symbol}, variable_col::Symbol, value_col::Symbol)
    if !all(col -> col ∈ propertynames(df), [variable_col, value_col])
        throw(ArgumentError("DataFrame must contain '$variable_col' and '$value_col' columns for wide format"))
    end
    return unstack(df, id_cols, variable_col, value_col)
end

"""
    reshape_long(df::DataFrame; id_cols::Vector{Symbol}=Symbol[], view::Bool=true)

Reshape a DataFrame from wide to long format.

# Arguments
- `df::DataFrame`: Input DataFrame
- `id_cols::Vector{Symbol}`: Columns to use as identifiers when stacking
- `view::Bool`: Whether to return a view of the DataFrame instead of a copy

# Examples
```julia
df_wide = DataFrame(id=[1,2], a=[10,20], b=[30,40])
df_long = reshape_long(df_wide, :time, :component_id, :value)
```
"""
function reshape_long(df::DataFrame; id_cols::Vector{Symbol}=Symbol[], view::Bool=true)
    if isempty(id_cols)
        return stack(df, view=view)
    else
        return stack(df, Not(id_cols), view=view)
    end
end