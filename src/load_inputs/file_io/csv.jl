###### ###### ###### ###### ###### ######
# CSV file handling
###### ###### ###### ###### ###### ######

function read_csv(
    file_path::AbstractString,
    sink::T = DataFrame;
    select::Vector{Symbol} = Symbol[],
) where {T}
    if length(select) > 0
        @info("Loading columns $select from CSV data from $file_path")
        csv_data = CSV.read(file_path, sink, select = select)
        isempty(csv_data) && error("Columns $select not found in $file_path")
        return csv_data
    end
    @info("Loading CSV data from $file_path")
    return CSV.read(file_path, sink)
end

function csv_header(path::AbstractString)
    f = open(path, "r")
    header = readline(f)
    close(f)
    header
end