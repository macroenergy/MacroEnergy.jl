###### ###### ###### ###### ###### ######
# CSV file handling
###### ###### ###### ###### ###### ######

# Cache full-file reads so that many assets pulling different columns out of
# the same wide CSV (e.g. hundreds of VRE availability profiles in one file)
# don't each pay for a fresh parse of the whole file.
const _CSV_READ_CACHE = Dict{String,Tuple{Float64,DataFrame}}()
const _CSV_READ_CACHE_LOCK = ReentrantLock()

function _cached_csv_read(file_path::AbstractString)::DataFrame
    key = abspath(file_path)
    current_mtime = mtime(key)
    lock(_CSV_READ_CACHE_LOCK) do
        cached = get(_CSV_READ_CACHE, key, nothing)
        if cached !== nothing && cached[1] == current_mtime
            return cached[2]
        end
        data = CSV.read(key, DataFrame)
        _CSV_READ_CACHE[key] = (current_mtime, data)
        return data
    end
end

function clear_csv_cache!()
    lock(_CSV_READ_CACHE_LOCK) do
        empty!(_CSV_READ_CACHE)
    end
    return nothing
end

function read_csv(file_path::AbstractString, select::Vector{Symbol} = Symbol[])::DataFrame
    @debug("Loading CSV data from $file_path")
    data = _cached_csv_read(file_path)
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

function _csv_header_record(io::IO)
    record = UInt8[]
    quoted = false
    while !eof(io)
        byte = read(io, UInt8)
        push!(record, byte)
        byte == UInt8('"') && (quoted = !quoted)
        if !quoted && byte in (UInt8('\n'), UInt8('\r'))
            # Match CSV's default handling of leading empty rows.
            all(value -> value in (UInt8('\n'), UInt8('\r')), record) || break
            empty!(record)
        end
    end
    return record
end

"""
    csv_headers(file_path::AbstractString)::Vector{Symbol}

Return CSV column names, reusing a fresh full-table cache entry when available.
On a cache miss, read at most ten logical records so CSV.jl can detect the
delimiter and parse the headers. Quoted newlines and escaped quotes are
preserved; gzip input is decompressed through a scoped stream. Header requests
never populate the full-table cache or leave file mappings alive.
"""
function csv_headers(file_path::AbstractString)::Vector{Symbol}
    key = abspath(file_path)
    current_mtime = mtime(key)
    cached_headers = lock(_CSV_READ_CACHE_LOCK) do
        cached = get(_CSV_READ_CACHE, key, nothing)
        cached !== nothing && cached[1] == current_mtime ? propertynames(cached[2]) : nothing
    end
    isnothing(cached_headers) || return cached_headers
    # GZip streams also read uncompressed files transparently.
    sample = GZip.open(key, "r") do io
        bytes = UInt8[]
        # CSV's automatic delimiter detection samples ten logical rows.
        for _ in 1:10
            record = _csv_header_record(io)
            isempty(record) && break
            append!(bytes, record)
        end
        bytes
    end
    return CSV.Rows(sample; buffer_in_memory=true).names
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
