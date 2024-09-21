###### ###### ###### ###### ###### ######
# Internal functions to handle loading the system_data.json file
###### ###### ###### ###### ###### ######

"""
    load_system_data(file_path::AbstractString, rel_path::AbstractString; default_file_path::String = joinpath(@__DIR__, "default_system_data.json"), lazy_load::Bool = true)::Dict{Symbol,Any}

Load the system data (currently only from a JSON file) given a file path and directory to search for the file in.
All other file names defined in the system data file are assumed to be relative to rel_path.
"""
function load_system_data(
    file_path::AbstractString,
    rel_path::AbstractString;
    default_file_path::String = joinpath(@__DIR__, "default_system_data.json"),
    lazy_load::Bool = true,
)::Dict{Symbol,Any}
    file_path = abspath(rel_or_abs_path(file_path, rel_path))

    prep_system_data(file_path, default_file_path)

    # Load the system data from the JSON file(s)
    return load_json_inputs(file_path; lazy_load = lazy_load)
end

"""
    load_system_data(file_path::AbstractString; default_file_path::String = joinpath(@__DIR__, "default_system_data.json"), lazy_load::Bool = true)::Dict{Symbol,Any}

Load the system data (currently only from a JSON file) given a file_path.
All other file names defined in the system data file are assumed to be relative to the parent directory of file_path.
"""
function load_system_data(
    file_path::AbstractString;
    default_file_path::String = joinpath(@__DIR__, "default_system_data.json"),
    lazy_load::Bool = true,
)::Dict{Symbol,Any}
    return load_system_data(
        file_path,
        dirname(file_path),
        default_file_path = default_file_path,
        lazy_load = lazy_load,
    )
end

"""
    load_system_data(system::System, file_path::AbstractString)::Dict{Symbol,Any}

Load the system data (currently only from a JSON file) given a file path and existing System.
All other file names defined in the system data file are assumed to be relative to the data_dirpath field of the System.
"""
function load_system_data(
    system::System, 
    file_path::AbstractString
)::Dict{Symbol,Any}
    return load_system_data(file_path, system.data_dirpath)
end

"""
    load_default_system_data(default_file_path::String)::Dict{Symbol,Any}

Load the default system data from a JSON file. 
This describes the default locations for the system data files.
"""
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

"""
    add_default_system_data!(system_data::AbstractDict{Symbol,Any}, default_file_path::String)::Nothing

Add the default system data to the system data dictionary. This adds any required fields that are missing.
"""
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

"""
    prep_system_data(file_path::AbstractString, default_file_path::String)::Nothing

This attempts to load the system data from the file at file_path, adds any missing fields from the default system data, and writes the updated system data back to the file.
In the future, we may change this to not write to the file, but for now, it's a quick way to ensure the system data is up-to-date.
"""
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

    # FIXME currently overwriting and then re-reading the system_data
    # This is a little janky, but lets us quickly use the JSON parsing functions
    open(file_path, "w") do io
        JSON3.pretty(io, system_data)
    end
    return nothing
end