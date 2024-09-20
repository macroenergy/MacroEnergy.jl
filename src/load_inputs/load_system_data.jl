###### ###### ###### ###### ###### ######
# Internal functions to handle loading the system_data.json file
###### ###### ###### ###### ###### ######

function load_system_data(
    file_path::AbstractString;
    default_file_path::String = joinpath(@__DIR__, "default_system_data.json"),
    lazy_load::Bool = true,
)::Dict{Symbol,Any}
    load_system_data(
        file_path,
        dirname(file_path),
        default_file_path = default_file_path,
        lazy_load = lazy_load,
    )
    return load_json(file_path; lazy_load = lazy_load)
end

function load_system_data(
    file_path::AbstractString,
    rel_path::AbstractString;
    default_file_path::String = joinpath(@__DIR__, "default_system_data.json"),
    lazy_load::Bool = true,
)::Dict{Symbol,Any}
    file_path = abspath(rel_or_abs_path(file_path, rel_path))

    prep_system_data(file_path, default_file_path)

    # Load the system data from the JSON file(s)
    return load_json(file_path; lazy_load = lazy_load)
end

function load_system_data!(
    system::System,
    file_path::AbstractString,
    default_file_path::String = joinpath(@__DIR__, "default_system_data.json"),
)::Nothing
    # Load the provided system data
    # We're assuming the file_path is a JSON file, not a directory
    file_path = abspath(rel_or_abs_path(file_path, system.data_dirpath))

    # Make sure the default arguments are included
    prep_system_data(file_path, default_file_path)

    # Load the system data from the JSON file(s)
    system_data = load_json(file_path)

    # Configure the model
    load_system_data!(system, system_data)
    return nothing
end


function load_default_system_data(
    default_file_path::String = joinpath(@__DIR__, "default_system_data.json"),
)::Dict{Symbol,Any}
    if isfile(default_file_path)
        default_system_data = read_json(default_file_path)
    else
        @warn("No default system data file found at $default_file_path")
    end
    return default_system_data
end

function add_default_system_data!(
    system_data::AbstractDict{Symbol,Any},
    default_file_path::String = joinpath(@__DIR__, "default_system_data.json"),
)::Nothing
    # Load a hard-coded set of default locations for the system data
    # This could be moved to the settings defaults later
    default_system_data = load_default_system_data(default_file_path)
    merge!(default_system_data, system_data)
    return nothing
end

function prep_system_data(
    file_path::AbstractString,
    default_file_path::String = joinpath(@__DIR__, "default_system_data.json"),
)::Nothing
    if isfile(file_path)
        system_data = read_json(file_path)
    else
        error("No system data file found at $file_path")
    end

    # Load a hard-coded set of default locations for the system data
    # This could be moved to the settings defaults later
    add_default_system_data!(system_data, default_file_path)

    # FIXME currenltly overwriting and then re-reading the system_data
    # This is a little janky, but lets us quickly use the JSON parsing functions
    open(file_path, "w") do io
        JSON3.pretty(io, system_data)
    end
    return nothing
end