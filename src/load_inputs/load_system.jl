###### ###### ###### ###### ###### ######
# Functions for the user to load a system based on JSON files
###### ###### ###### ###### ###### ######

function load_system(path::AbstractString = pwd())::System

    # The path should either be a a file path to a JSON file, preferably "system_data.json"
    # or a directory containing "system_data.json"
    # We'll check the absolute path first, then the path relative to the working directory

    # If path ends with ".json", we assume it's a file
    if isjson(path)
        path = rel_or_abs_path(path)
    else
        # Assume it's a dir, ignoring other possible suffixes
        path = rel_or_abs_path(joinpath(path, "system_data.json"))
    end

    if isfile(path)
        system = empty_system(dirname(path))
        system_data = load_system_data(path)
        generate_system!(system, system_data)
        return system
    else
        throw(
            ArgumentError(
                "
    No system data found in $path
    Either provide a path to a .JSON file or a directory containing a system_data.json file
",
            ),
        )
    end
end

function load_system(
    system_data::AbstractDict{Symbol,Any},
    dir_path::AbstractString = pwd(),
)::System
    # The path should point to the location of the system data files
    # If path is not provided, we assume the data is in the current working directory
    if isfile(dir_path)
        dir_path = dirname(dir_path)
    end
    system = empty_system(dir_path)
    generate_system!(system, system_data)
    return system
end