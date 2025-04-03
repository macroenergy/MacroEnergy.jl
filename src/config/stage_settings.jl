function default_stage_settings()
    return Dict(
        :StageLengths => [1],
        :WACC => 0.,
        :SolutionAlgorithm => "SingleStage",
    )
end

function configure_stages(
    path::AbstractString,
    rel_path::AbstractString,
)
    path = rel_or_abs_path(path, rel_path)
    if isdir(path)
        path = joinpath(path, "stage_settings.json")
    end
    if !isfile(path)
        error("Settings file not found: $path")
    end
    return configure_stages(read_file(path))
end

function configure_stages(
    stage_settings::AbstractDict{Symbol,Any},
    rel_path::AbstractString,
)
    if haskey(stage_settings, :path)
        @info("Configuring stages from path")
        path = rel_or_abs_path(stage_settings[:path], rel_path)
        return configure_stages(path, rel_path)
    else
        return configure_stages(stage_settings)
    end
end

function configure_stages(stage_settings::AbstractDict{Symbol,Any})
    @info("Configuring stages")
    settings = default_stage_settings()
    settings = merge(settings, stage_settings)
    set_stage_lengths!(settings)
    set_solution_algorithm!(settings)
    validate_stage_settings(settings)
    return namedtuple(settings)
end

function validate_stage_settings(stage_settings::AbstractDict{Symbol,Any})
    @assert all(stage_settings[:StageLengths].>0)
    @assert stage_settings[:WACC] >= 0
    @assert isa(stage_settings[:SolutionAlgorithm], AbstractSolutionAlgorithm)
end

function set_stage_lengths!(stage_settings::AbstractDict{Symbol,Any})
    stage_settings[:StageLengths] = copy(stage_settings[:StageLengths])
    return nothing
end

function set_solution_algorithm!(stage_settings::AbstractDict{Symbol,Any})
    @info("Setting solution algorithm")
    if stage_settings[:SolutionAlgorithm] == "Myopic"
        stage_settings[:SolutionAlgorithm] = Myopic()
    elseif stage_settings[:SolutionAlgorithm] == "PerfectForesight"
        stage_settings[:SolutionAlgorithm] = PerfectForesight()
    elseif stage_settings[:SolutionAlgorithm] == "SingleStage"
        stage_settings[:SolutionAlgorithm] = SingleStage()
    elseif stage_settings[:SolutionAlgorithm] == "Benders"
        stage_settings[:SolutionAlgorithm] = Benders()
    else
        @warn("No solution algorithm specified, defaulting to SingleStage")
        stage_settings[:SolutionAlgorithm] = SingleStage()
    end
    @info("Solution algorithm set to $(stage_settings[:SolutionAlgorithm])")
    return nothing
end