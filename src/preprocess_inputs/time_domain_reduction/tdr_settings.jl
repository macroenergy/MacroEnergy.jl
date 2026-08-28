abstract type AbstractTDRMethodSettings end

Base.@kwdef struct TDRKMeansSettings <: AbstractTDRMethodSettings
    restarts::Int = 0
    verbose::Bool = false
end

Base.@kwdef struct TDRKMedoidsSettings <: AbstractTDRMethodSettings
    restarts::Int = 0
    verbose::Bool = false
end

Base.@kwdef struct TDRExtremePeriodSpec
    feature::TDRFeatureSpec
    aggregation::Symbol
    select::Symbol
end

Base.@kwdef struct TDRSettings
    timesteps_per_representative_period::Int
    representative_periods::Int
    method_settings::AbstractTDRMethodSettings
    scaling::Symbol
    all_features::Vector{TDRFeatureSpec}
    features::Vector{TDRFeatureSpec}
    excluded_features::Vector{TDRFeatureSpec}
    extreme_periods::Vector{TDRExtremePeriodSpec}
end

"""
    load_time_domain_reduction_settings(path) -> TDRSettings

Load and validate the JSON settings used by [`preprocess_inputs`](@ref).
"""
function load_time_domain_reduction_settings(path::AbstractString)::TDRSettings
    isfile(path) || throw(ArgumentError("TDR settings file does not exist: $(abspath(path))"))
    data = mutable_json_data(read_json(path))
    required = ("timesteps_per_representative_period", "representative_periods", "method", "scaling")
    for key in required
        haskey(data, key) || throw(ArgumentError("TDR settings are missing `$key`."))
    end
    period_length = data["timesteps_per_representative_period"]
    n_periods = data["representative_periods"]
    period_length isa Integer && period_length > 0 || throw(ArgumentError("`timesteps_per_representative_period` must be a positive integer."))
    n_periods isa Integer && n_periods > 0 || throw(ArgumentError("`representative_periods` must be a positive integer."))
    method_settings = load_tdr_method_settings(data["method"])
    scaling = Symbol(data["scaling"])
    scaling in (:standardize, :normalize) || throw(ArgumentError("TDR `scaling` must be `standardize` or `normalize`."))
    user_features = TDRFeatureSpec[tdr_feature_spec(feature) for feature in get(data, "features", Any[])]
    exclusions = TDRFeatureSpec[tdr_feature_spec(selector; require_field=false) for selector in get(data, "exclude", Any[])]
    all_features = tdr_merge_features(user_features)
    active_features = [
        feature for feature in all_features if !any(exclusion -> tdr_feature_matches_selector(feature, exclusion), exclusions)
    ]
    extreme_periods_data = get(data, "extreme_periods", Any[])
    extreme_periods_data isa AbstractVector ||
        throw(ArgumentError("TDR `extreme_periods` must be an array."))
    extreme_periods = TDRExtremePeriodSpec[
        tdr_extreme_period_spec(specification) for specification in extreme_periods_data
    ]
    return TDRSettings(
        timesteps_per_representative_period=Int(period_length),
        representative_periods=Int(n_periods),
        method_settings=method_settings,
        scaling=scaling,
        all_features=all_features,
        features=active_features,
        excluded_features=exclusions,
        extreme_periods=extreme_periods,
    )
end

function tdr_extreme_period_spec(data::AbstractDict)
    for key in ("feature", "aggregation", "select")
        haskey(data, key) || throw(ArgumentError("Each extreme-period specification must define `$key`."))
    end
    data["feature"] isa AbstractDict || throw(ArgumentError("Extreme-period `feature` must be an object."))
    data["aggregation"] isa AbstractString || throw(ArgumentError("Extreme-period `aggregation` must be a string."))
    data["select"] isa AbstractString || throw(ArgumentError("Extreme-period `select` must be a string."))
    aggregation = Symbol(data["aggregation"])
    select = Symbol(data["select"])
    aggregation in (:integral, :absolute) ||
        throw(ArgumentError("Extreme-period `aggregation` must be `integral` or `absolute`."))
    select in (:max, :min) ||
        throw(ArgumentError("Extreme-period `select` must be `max` or `min`."))
    return TDRExtremePeriodSpec(
        feature=tdr_feature_spec(data["feature"]),
        aggregation=aggregation,
        select=select,
    )
end

function load_tdr_method_settings(method_data)::AbstractTDRMethodSettings
    method_data isa AbstractDict || throw(ArgumentError("TDR `method` must be an object with `name` and `settings`."))
    haskey(method_data, "name") || throw(ArgumentError("TDR method is missing `name`."))
    method_data["name"] isa AbstractString || throw(ArgumentError("TDR method `name` must be a string."))
    settings_data = get(method_data, "settings", Dict{String,Any}())
    settings_data isa AbstractDict || throw(ArgumentError("TDR method `settings` must be an object."))
    restarts = get(settings_data, "restarts", 0)
    restarts isa Integer && restarts >= 0 || throw(ArgumentError("TDR method setting `restarts` must be a non-negative integer."))
    verbose = get(settings_data, "v", false)
    verbose isa Bool || throw(ArgumentError("TDR method setting `v` must be a boolean."))
    method = String(method_data["name"])
    if method == "kmeans"
        return TDRKMeansSettings(restarts=Int(restarts), verbose=verbose)
    elseif method == "kmedoids"
        return TDRKMedoidsSettings(restarts=Int(restarts), verbose=verbose)
    end
    throw(ArgumentError("TDR `method.name` must be `kmeans` or `kmedoids`."))
end
