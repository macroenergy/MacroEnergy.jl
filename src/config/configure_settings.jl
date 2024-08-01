function default_settings()
    (
        UCommit=false,
        NetworkExpansion=false,
    )
end

namedtuple(d::Dict) = (; (Symbol(k) => v for (k, v) in d)...)
function configure_settings(settings_path::String)
    model_settings = namedtuple(YAML.load_file(settings_path))

    validate_names(model_settings)
    settings = default_settings()

    settings = merge(settings, model_settings)

    validate_settings(settings)
    return settings
end

function validate_settings(settings::NamedTuple)
    nothing
    # # Check that input/output paths are valid
    # @assert isa(settings[:InputDataPath], String) && isdir(settings[:InputDataPath])
    # @assert isa(settings[:OutputDataPath], String)
    # @assert settings[:PrintModel] ∈ (0, 1)
    # @assert settings[:NetworkExpansion] ∈ (0, 1)
    # @assert settings[:TimeDomainReduction] ∈ (0, 1)
    # @assert isa(settings[:TimeDomainReductionFolder], String)
    # @assert settings[:MultiStage] ∈ (0, 1)
end

function validate_names(settings::NamedTuple)
    # Check that all the names in the settings file are valid
    valid_names = keys(default_settings())
    unknown_names = setdiff(keys(settings), valid_names)
    if !isempty(unknown_names)
        error("Unknown settings: $(unknown_names)")
    end
end

function configure_time_interval!(macro_settings::NamedTuple, commodities::Dict{Symbol,DataType}=commodity_types(Macro))
    time_intervals = Dict{Any, StepRange{Int64, Int64}}()
    subperiods = Dict{Any, Vector{StepRange{Int64, Int64}}}()
    for (name, time_details) in macro_settings[:Commodities]
        commodity_type = commodities[Symbol(name)]

        period_length = macro_settings[:PeriodLength]
        hours_per_timestep = time_details["HoursPerTimeStep"]
        hours_per_subperiod = time_details["HoursPerSubperiod"]
        
        time_interval = 1:hours_per_timestep:period_length
        time_intervals[commodity_type] = time_interval
        
        subperiods[commodity_type] = collect(
            Iterators.partition(time_interval, Int(hours_per_subperiod / hours_per_timestep)),
        )
    end
    macro_settings = merge(macro_settings, [:TimeIntervals=>time_intervals, :SubPeriods=>subperiods])
    return macro_settings    
end
