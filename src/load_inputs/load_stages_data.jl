function load_stages_data(
    file_path::AbstractString,
    rel_path::AbstractString = dirname(file_path);
    lazy_load::Bool = true,
)::Dict{Symbol,Any}
    file_path = abspath(rel_or_abs_path(file_path, rel_path))

    # Load the system data from the JSON file(s)
    data = load_system_data(file_path, rel_path; lazy_load = lazy_load)

    # Convert a single stage system to a vector of stages 
    # to unify the interface with multistage systems
    if !haskey(data, :stages)
        data = Dict(:stages => [data],
            :settings => default_stage_settings() # default stage settings: single stage, no discounting
        )
    end

    return data
end

function load_stages(
    path::AbstractString = pwd();
    lazy_load::Bool=true,
)::Stages

    # The path should either be a a file path to a JSON file, preferably "system_data.json"
    # or a directory containing "system_data.json"

    if isdir(path)
        path = joinpath(path, "system_data.json")
    end

    if isjson(path)
        @info("Loading stages from $path")
        start_time = time()

        systems_data = load_stages_data(path; lazy_load = lazy_load)
        stages = generate_stages(path, systems_data)

        @info("Done loading system. It took $(round(time() - start_time, digits=2)) seconds")
        return stages
    else
        msg = "No stages data found in $path. Either provide a path to a .JSON file or a directory containing a system_data.json file"
        throw(ArgumentError(msg))
    end
end