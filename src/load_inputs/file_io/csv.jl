###### ###### ###### ###### ###### ######
# CSV file handling
###### ###### ###### ###### ###### ######

function read_csv(file_path::AbstractString; select::Vector{Symbol} = Symbol[])::DataFrame
    data = DataFrame(duckdb_read(file_path))
    if length(select) > 0
        @info("Loading columns $select from CSV data from $file_path")
        select!(data, select)
        isempty(data) && error("Columns $select not found in $file_path")
    else
        @info("Loading CSV data from $file_path")
    end
    @info("Loading CSV data from $file_path")
    return data
end

function csv_header(path::AbstractString)
    f = open(path, "r")
    header = readline(f)
    close(f)
    header
end

const CSV_EXT = (".csv", ".csv.gz")

iscsv(path::AbstractString) = any(endswith.(path, CSV_EXT))