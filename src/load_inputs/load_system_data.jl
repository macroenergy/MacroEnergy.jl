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
    rel_path::AbstractString = dirname(file_path);
    default_file_path::String = joinpath(@__DIR__, "default_system_data.json"),
    lazy_load::Bool = true,
)::Dict{Symbol,Any}
    file_path = abspath(rel_or_abs_path(file_path, rel_path))

    prep_system_data(file_path, default_file_path)

    # Load the system data from the JSON file(s)
    return load_json_inputs(file_path; rel_path=rel_path, lazy_load = lazy_load)
end

"""
    load_system_data(system::System, file_path::AbstractString)::Dict{Symbol,Any}

Load the system data (currently only from a JSON file) given a file path and existing System.
All other file names defined in the system data file are assumed to be relative to the data_dirpath field of the System.
"""
function load_system_data(
    file_path::AbstractString,
    system::System, 
)::Dict{Symbol,Any}
    return load_system_data(file_path, system.data_dirpath)
end