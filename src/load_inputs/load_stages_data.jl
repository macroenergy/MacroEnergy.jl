function load_case_data(
    file_path::AbstractString,
    rel_path::AbstractString = dirname(file_path);
    lazy_load::Bool = true,
)::Dict{Symbol,Any}
    start_time = time()
    file_path = abspath(rel_or_abs_path(file_path, rel_path))

    # Clear the CSV cache at the start of each case load
    clear_csv_cache!()

    # Load the system data from the JSON file(s)
    data = load_system_data(file_path, rel_path; lazy_load = lazy_load)

    # Convert a single period system to a vector of case 
    if !haskey(data, :case)
        data = Dict(
            :case => [data],
            :settings => single_system_case_settings(file_path)
        )
    end

    @info("Done loading case data. It took $(round(time() - start_time, digits=2)) seconds")
    return data
end

function load_case(
    path::AbstractString = pwd();
    lazy_load::Bool=true,
)::Case

    # The path should either be a a file path to a JSON file, preferably "system_data.json"
    # or a directory containing "system_data.json"

    if isdir(path)
        path = joinpath(path, "system_data.json")
    end

    if isjson(path)
        @info("Loading case from $path")

        try
            case_data = load_case_data(path; lazy_load = lazy_load)
            return generate_case(path, case_data)
        finally
            # Release the cached input CSVs now that every System owns its own copy (or if the load failed)
            clear_csv_cache!()
        end
    else
        msg = "No case data found in $path. Either provide a path to a .JSON file or a directory containing a system_data.json file"
        throw(ArgumentError(msg))
    end
end

function single_system_case_settings(file_path::AbstractString)::Dict{Symbol,Any}
    case_settings_path = joinpath(dirname(file_path), "settings", STAGE_SETTINGS_FILENAME)
    if isfile(case_settings_path)
        return Dict{Symbol,Any}(:path => case_settings_path)
    end
    return default_case_settings()
end