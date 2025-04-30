function default_stage_settings()
    return Dict(
        :StageLengths => [1],
        :WACC => 0.,
        :ExpansionMode => "SingleStage",
        :SolutionAlgorithm => "Monolithic",
    )
end

function default_benders_settings()
    return Dict(
        :MaxIter=> 50,
        :MaxCpuTime => 7200,
        :ConvTol => 1e-3,
        :StabParam => 0.0,
        :StabDynamic => false,
        :IntegerInvestment => false,
        :Distributed => false,
        :IncludeAutomaticSlackPenalty => false,
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
        error("Stage settings file not found: $path")
    end
    
    # Load stage settings
    stage_settings = copy(read_file(path))
    
    # Load benders settings if they exist
    benders_path = joinpath(dirname(path), "benders_settings.json")
    if isfile(benders_path)
        benders_settings = read_file(benders_path)
        stage_settings[:BendersSettings] = benders_settings
    end
    
    return configure_stages(stage_settings)
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
    set_expansion_mode!(settings)
    set_solution_algorithm!(settings)
    isa(settings[:SolutionAlgorithm], Benders) && configure_benders!(settings)
    validate_stage_settings(settings)
    return namedtuple(settings)
end

function validate_stage_settings(stage_settings::AbstractDict{Symbol,Any})
    @assert all(stage_settings[:StageLengths].>0)
    @assert stage_settings[:WACC] >= 0
    @assert isa(stage_settings[:ExpansionMode], AbstractExpansionMode)
    @assert isa(stage_settings[:SolutionAlgorithm], AbstractSolutionAlgorithm)
end

function set_stage_lengths!(stage_settings::AbstractDict{Symbol,Any})
    stage_settings[:StageLengths] = copy(stage_settings[:StageLengths])
    return nothing
end

function set_expansion_mode!(stage_settings::AbstractDict{Symbol,Any})
    @info("Setting expansion mode")
    if stage_settings[:ExpansionMode] == "Myopic"
        stage_settings[:ExpansionMode] = Myopic()
    elseif stage_settings[:ExpansionMode] == "PerfectForesight"
        stage_settings[:ExpansionMode] = PerfectForesight()
    elseif stage_settings[:ExpansionMode] == "SingleStage"
        stage_settings[:ExpansionMode] = SingleStage()
    else
        @warn("No expansion mode specified, defaulting to SingleStage")
        stage_settings[:ExpansionMode] = SingleStage()
    end
    @info("Expansion mode set to $(stage_settings[:ExpansionMode])")
    return nothing
end

function set_solution_algorithm!(stage_settings::AbstractDict{Symbol,Any})
    @info("Setting solution algorithm")
    if stage_settings[:SolutionAlgorithm] == "Monolithic"
        stage_settings[:SolutionAlgorithm] = Monolithic()
    elseif stage_settings[:SolutionAlgorithm] == "Benders"
        stage_settings[:SolutionAlgorithm] = Benders()
    else
        @warn("No solution algorithm specified, defaulting to Monolithic")
        stage_settings[:SolutionAlgorithm] = Monolithic()
    end
    @info("Solution algorithm set to $(stage_settings[:SolutionAlgorithm])")
    return nothing
end

function configure_benders!(stage_settings::AbstractDict{Symbol,Any})
    # use default benders settings if BendersSettings is not specified
    benders_settings = get(stage_settings, :BendersSettings, Dict{Symbol,Any}())
    @info("Configuring benders")
    settings = default_benders_settings()
    settings = merge(settings, benders_settings)
    validate_benders_settings(settings)
    stage_settings[:BendersSettings] = settings
    return nothing
end

function validate_benders_settings(benders_settings::AbstractDict{Symbol,Any})
    @assert benders_settings[:MaxIter] > 0 && isa(benders_settings[:MaxIter], Int)
    @assert benders_settings[:MaxCpuTime] > 0 && isa(benders_settings[:MaxCpuTime], Int)
    @assert benders_settings[:ConvTol] > 0 && isa(benders_settings[:ConvTol], Number)
    @assert benders_settings[:StabParam] >= 0 && isa(benders_settings[:StabParam], Number)
    @assert isa(benders_settings[:StabDynamic], Bool)
    @assert isa(benders_settings[:IntegerInvestment], Bool)
end