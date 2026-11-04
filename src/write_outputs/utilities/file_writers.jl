"""
CSV writing functions for output data.
"""

# Function to write a DataFrame to a CSV file
function write_csv(file_path::AbstractString, data::AbstractDataFrame, compress::Bool=false)
    CSV.write(file_path, data, compress=compress)
end

"""
Parquet writing functions for output data.
"""

# Function to write a DataFrame to a zstd-compressed Parquet file
function write_parquet(file_path::AbstractString, data::DataFrame)
    # Parquet2 does not support Symbol columns
    # Convert Symbol columns (including those with missing values) to String in place
    for col in names(data)
        if nonmissingtype(eltype(data[!, col])) <: Symbol
            data[!, col] = passmissing(string).(data[!, col])
        end
    end
    Parquet2.writefile(file_path, data; compression_codec=:zstd)
end
