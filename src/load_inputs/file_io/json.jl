###### ###### ###### ###### ###### ######
# JSON file handling
###### ###### ###### ###### ###### ######

function read_json(file_path::AbstractString)
    io = open(file_path, "r")
    json_data = JSON3.read(io)
    close(io)
    return json_data
end

function write_json(file_path::AbstractString, data::Dict{Symbol,Any})::Nothing
    io = open(file_path, "w")
    JSON3.pretty(io, data)
    close(io)
    return nothing
end