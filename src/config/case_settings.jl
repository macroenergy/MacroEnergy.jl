# Constants for file paths
const STAGE_SETTINGS_FILENAME = "case_settings.json"
const BENDERS_SETTINGS_FILEPATH = "settings/benders_settings.json"

function default_case_settings()
    return Dict(
        :PeriodLengths => [1],
        :DiscountRate => 0.,
        :SolutionAlgorithm => "Monolithic"
    )
end

function default_myopic_settings()
    return Dict(
        :ReturnModels => false,
        :WriteModelLP => false,
        :Restart => Dict(:enabled=>false, :folder => "results_001", :from_period => 1),
        :StopAfterPeriod => Inf
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
        :ExpectFeasibleSubproblems => false,
        :IncludeSubproblemSlacksAutomatically => false
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

function configure_case(
    path::AbstractString,
    rel_path::AbstractString,
)
    path = rel_or_abs_path(path, rel_path)
    if isdir(path)
        path = joinpath(path, STAGE_SETTINGS_FILENAME)
    end
    
    if !isfile(path)
        error("Period settings file not found: $path")
    end
    
    # Load case settings
    case_settings = copy(read_file(path))
    
    # Check for BendersSettings path if Benders is the solution algorithm
    if case_settings[:SolutionAlgorithm] == "Benders"
        case_settings = load_benders_settings(case_settings, rel_path)
    end
    
    return configure_case(case_settings)
end

function configure_case(
    case_settings::AbstractDict{Symbol,Any},
    rel_path::AbstractString,
)
    if haskey(case_settings, :path)
        @info("Configuring case from $(case_settings[:path])")
        path = rel_or_abs_path(case_settings[:path], rel_path)
        return configure_case(path, rel_path)
    else
        # if Benders is the solution algorithm and BendersSettings is not specified 
        # in the case_settings, try to load the Benders settings from the default location
        if case_settings[:SolutionAlgorithm] == "Benders" && 
            !haskey(case_settings, :BendersSettings)
            benders_settings = try_load_benders_settings(rel_path)
            if !isnothing(benders_settings)
                case_settings[:BendersSettings] = benders_settings
            end
        end
        return configure_case(case_settings)
    end
end

function configure_case(case_settings::AbstractDict{Symbol,Any})
    @info("Configuring case")
    settings = default_case_settings()
    settings = merge(settings, case_settings)
    set_period_lengths!(settings)
    set_solution_algorithm!(settings)
    isa(settings[:SolutionAlgorithm], Benders) && configure_benders!(settings)
    isa(settings[:SolutionAlgorithm], Myopic) && configure_myopic!(settings)
    validate_case_settings(settings)
    return namedtuple(settings)
end

function validate_case_settings(case_settings::AbstractDict{Symbol,Any})
    @assert all(case_settings[:PeriodLengths].>0)
    @assert case_settings[:DiscountRate] >= 0
    @assert isa(case_settings[:SolutionAlgorithm], AbstractSolutionAlgorithm)
end

function set_period_lengths!(case_settings::AbstractDict{Symbol,Any})
    case_settings[:PeriodLengths] = copy(case_settings[:PeriodLengths])
    return nothing
end


function set_solution_algorithm!(case_settings::AbstractDict{Symbol,Any})
    @info(" -- Setting solution algorithm")
    if case_settings[:SolutionAlgorithm] == "Monolithic"
        case_settings[:SolutionAlgorithm] = Monolithic()
    elseif case_settings[:SolutionAlgorithm] == "Benders"
        case_settings[:SolutionAlgorithm] = Benders()
    elseif case_settings[:SolutionAlgorithm] == "Myopic"
        case_settings[:SolutionAlgorithm] = Myopic()
    else
        @warn("No solution algorithm specified, defaulting to Monolithic")
        case_settings[:SolutionAlgorithm] = Monolithic()
    end
    @info(" -- Solution algorithm set to $(case_settings[:SolutionAlgorithm])")
    return nothing
end

function configure_benders!(case_settings::AbstractDict{Symbol,Any})
    # use default benders settings if BendersSettings is not specified
    benders_settings = get(case_settings, :BendersSettings, Dict{Symbol,Any}())
    isempty(benders_settings) && @warn("No benders settings specified, using default settings")
    @info("Configuring benders")
    settings = default_benders_settings()
    settings = merge(settings, benders_settings)
    validate_benders_settings(settings)
    case_settings[:BendersSettings] = settings
    return nothing
end

function configure_myopic!(case_settings::AbstractDict{Symbol,Any})
    # use default myopic settings if MyopicSettings is not specified
    myopic_settings = get(case_settings, :MyopicSettings, Dict{Symbol,Any}())
    isempty(myopic_settings) && @warn("No myopic settings specified, using default settings")
    @info("Configuring myopic")
    settings = default_myopic_settings()
    settings = merge(settings, myopic_settings)
    validate_myopic_settings(settings)
    case_settings[:MyopicSettings] = settings
    return nothing
end

function validate_benders_settings(benders_settings::AbstractDict{Symbol,Any})
    @assert benders_settings[:MaxIter] > 0 && isa(benders_settings[:MaxIter], Int)
    @assert benders_settings[:MaxCpuTime] > 0 && isa(benders_settings[:MaxCpuTime], Int)
    @assert benders_settings[:ConvTol] > 0 && isa(benders_settings[:ConvTol], Number)
    @assert benders_settings[:StabParam] >= 0 && isa(benders_settings[:StabParam], Number)
    @assert isa(benders_settings[:StabDynamic], Bool)
    @assert isa(benders_settings[:IntegerInvestment], Bool)
    @assert isa(benders_settings[:Distributed], Bool)
    @assert isa(benders_settings[:ExpectFeasibleSubproblems], Bool)
    @assert isa(benders_settings[:IncludeSubproblemSlacksAutomatically], Bool)
end

function validate_myopic_settings(myopic_settings::AbstractDict{Symbol,Any})
    @assert isa(myopic_settings[:ReturnModels], Bool)
    @assert isa(myopic_settings[:WriteModelLP], Bool)
    @assert isa(myopic_settings[:Restart][:enabled], Bool)
    @assert isa(myopic_settings[:Restart][:folder], AbstractString)
    @assert isa(myopic_settings[:Restart][:from_period], Int)
    @assert isa(myopic_settings[:StopAfterPeriod], Number)
    @assert myopic_settings[:StopAfterPeriod] >= 1
    @assert myopic_settings[:Restart][:from_period] >= 1
    @assert (!myopic_settings[:Restart][:enabled]) || (myopic_settings[:Restart][:from_period] <= myopic_settings[:StopAfterPeriod])

end