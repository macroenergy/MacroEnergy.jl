###### ###### ###### ###### ###### ######
# JSON file handling
###### ###### ###### ###### ###### ######

function read_json(file_path::AbstractString)
    iscompressed = endswith(file_path, ".json.gz")
    io = iscompressed ? GZip.open(file_path, "r") : open(file_path, "r")
    data = JSON3.read(io; allow_inf=true)
    close(io)
    return data
end

function write_json(file_path::AbstractString, data::AbstractDict, compress::Bool=false)::Nothing
    if compress || endswith(file_path, ".gz")
        if !endswith(file_path, ".gz")
            file_path *= ".gz"
        end
        io = GZip.open(file_path, "w")
    else
        io = open(file_path, "w")
    end
    JSON3.pretty(io, data; allow_inf=true)
    close(io)
    return nothing
end

macro JSON_EXT()
    return (".json", ".json.gz")
end

isjson(path::AbstractString) = any(endswith.(path, @JSON_EXT))

# Fetch all json files in the directory
function get_json_files(path::AbstractString)
    return filter(x -> any(endswith.(x, @JSON_EXT)), readdir(path))
end

"""Convert JSON3 containers into a recursively mutable, string-keyed tree."""
function mutable_json_data(value)
    if value isa AbstractDict || value isa JSON3.Object
        return Dict{String,Any}(String(key) => mutable_json_data(nested_value) for (key, nested_value) in pairs(value))
    elseif value isa AbstractVector || value isa JSON3.Array
        return [mutable_json_data(nested_value) for nested_value in value]
    end
    return value
end

"""Replace the value at a nested dictionary/vector path."""
function set_at_path!(data, path::Vector{Any}, value)
    target = data
    for key in path[1:end-1]
        target = target[key]
    end
    target[path[end]] = value
    return nothing
end
