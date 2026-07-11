###### ###### ###### ###### ###### ######
# CSV file handling
###### ###### ###### ###### ###### ######

# Cache full-file reads so that many assets pulling different columns out of
# the same wide CSV (e.g. hundreds of VRE availability profiles in one file)
# don't each pay for a fresh DuckDB sniff-and-read of the whole file.
const _CSV_READ_CACHE = Dict{String,DataFrame}()
const _CSV_READ_CACHE_LOCK = ReentrantLock()

function _cached_duckdb_read(file_path::AbstractString)::DataFrame
    key = abspath(file_path)
    lock(_CSV_READ_CACHE_LOCK) do
        get!(_CSV_READ_CACHE, key) do
            DataFrame(duckdb_read(file_path))
        end
    end
end

function read_csv(file_path::AbstractString, select::Vector{Symbol} = Symbol[])::DataFrame
    @debug("Loading CSV data from $file_path")
    data = _cached_duckdb_read(file_path)
    if length(select) > 0
        @debug("Loading columns $select from CSV data from $file_path")
        missing_cols = setdiff(select, propertynames(data))
        isempty(missing_cols) || error("Columns $missing_cols not found in $file_path")
        # Column-selecting copy: never mutate the cached DataFrame in place,
        # since it's shared across every caller that reads this file.
        return data[:, select]
    end
    return copy(data)
end

function read_csv(file_path::AbstractString, select::Symbol)::DataFrame
    return read_csv(file_path, [select])
end

function csv_header(path::AbstractString)
    f = open(path, "r")
    header = readline(f)
    close(f)
    header
end

macro CSV_EXT()
    return (".csv", ".csv.gz")
end

iscsv(path::AbstractString) = any(endswith.(path, @CSV_EXT))

function get_csv_files(path::AbstractString)
    return filter(x -> any(endswith.(x, @CSV_EXT)), readdir(path))
end