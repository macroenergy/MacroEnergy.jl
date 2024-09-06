# Exception to throw if an input file is not found
struct InputFileNotFound <: Exception
    filefullpath::String
end
Base.showerror(io::IO, e::InputFileNotFound) = print(io, e.filefullpath, " not found")


function load_dataframe(filepath::AbstractString)
    if isfile(filepath)
        validate_columns(filepath)
        return CSV.read(filepath, DataFrame, header = 1)
    else
        throw(InputFileNotFound(filepath))
    end
end

function csv_header(path::AbstractString)
    f = open(path, "r")
    header = readline(f)
    close(f)
    header
end

function keep_duplicated_entries!(s, uniques)
    for u in uniques
        deleteat!(s, first(findall(x -> x == u, s)))
    end
    return s
end

function check_for_duplicate_keys(path::AbstractString)
    header = csv_header(path)
    keys = split(header, ',')
    uniques = unique(keys)
    if length(keys) > length(uniques)
        dupes = keep_duplicated_entries!(keys, uniques)
        @error """Some duplicate column names detected in the header of $path: $dupes.
        Duplicate column names may cause errors, as only the first is used.
        """
    end
end

function validate_columns(path::AbstractString)
    check_for_duplicate_keys(path)
end
