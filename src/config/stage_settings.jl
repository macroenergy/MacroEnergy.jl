# Constants for file paths
const STAGE_SETTINGS_FILENAME = "stage_settings.json"
const BENDERS_SETTINGS_FILEPATH = "settings/benders_settings.json"

function default_stage_settings()
    return Dict(
        :StageLengths => [1],
        :WACC => 0.,
        :ExpansionMode => "SingleStage",
        :SolutionAlgorithm => "Monolithic"
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

"""
    try_load_benders_settings(path::AbstractString)::Union{AbstractDict{Symbol,Any}, Nothing}

Attempts to load Benders settings from the given path. Returns the settings if found, nothing otherwise.
"""
function try_load_benders_settings(path::AbstractString)::Union{AbstractDict{Symbol,Any}, Nothing}
    benders_path = joinpath(path, BENDERS_SETTINGS_FILEPATH)
    if isfile(benders_path)
        @debug("Loading Benders settings from default location: $benders_path")
        return read_file(benders_path)
    end
    return nothing
end

"""
    load_benders_settings(settings::AbstractDict{Symbol,Any}, path::AbstractString)::AbstractDict{Symbol,Any}

Load Benders settings from a file. First checks if a specific path is provided in the settings,
otherwise looks for benders_settings.json in the settings directory. Handles both absolute and relative paths.
"""
function load_benders_settings(settings::AbstractDict{Symbol,Any}, path::AbstractString)::AbstractDict{Symbol,Any}
    # Try to load from specified path if provided
    if haskey(settings, :BendersSettings) && 
       isa(settings[:BendersSettings], AbstractDict) && 
       haskey(settings[:BendersSettings], :path)

        benders_path = rel_or_abs_path(settings[:BendersSettings][:path], path)
        if isfile(benders_path)
            @info("Loading Benders settings from path: $benders_path")
            settings[:BendersSettings] = read_file(benders_path)
            return settings
        end
        
        @warn("Benders settings file not found at either absolute path '$(settings[:BendersSettings][:path])' or relative path '$benders_path'")
    end

    # Otherwise, try to load from default location defined as BENDERS_SETTINGS_FILEPATH
    benders_settings = try_load_benders_settings(path)
    if !isnothing(benders_settings)
        settings[:BendersSettings] = benders_settings
    end

    return settings
end

function configure_stages(
    path::AbstractString,
    rel_path::AbstractString,
)
    path = rel_or_abs_path(path, rel_path)
    if isdir(path)
        path = joinpath(path, STAGE_SETTINGS_FILENAME)
    end
    
    if !isfile(path)
        error("Stage settings file not found: $path")
    end
    
    # Load stage settings
    stage_settings = copy(read_file(path))
    
    # Check for BendersSettings path if Benders is the solution algorithm
    if stage_settings[:SolutionAlgorithm] == "Benders"
        stage_settings = load_benders_settings(stage_settings, rel_path)
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
        # if Benders is the solution algorithm and BendersSettings is not specified 
        # in the stage_settings, try to load the Benders settings from the default location
        if stage_settings[:SolutionAlgorithm] == "Benders" && 
            !haskey(stage_settings, :BendersSettings)
            benders_settings = try_load_benders_settings(rel_path)
            if !isnothing(benders_settings)
                stage_settings[:BendersSettings] = benders_settings
            end
        end
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
    isempty(benders_settings) && @warn("No benders settings specified, using default settings")
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