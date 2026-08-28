abstract type AbstractTDRMethodSettings end

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
    output_features::Union{Nothing,TDROutputFeaturesSettings} = nothing
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
    output_features = load_tdr_output_features(get(data, "output_based_features", nothing))
    return TDRSettings(
        timesteps_per_representative_period=Int(period_length),
        representative_periods=Int(n_periods),
        method_settings=method_settings,
        scaling=scaling,
        all_features=all_features,
        features=active_features,
        excluded_features=exclusions,
        extreme_periods=extreme_periods,
        output_features=output_features,
    )
end

function load_tdr_output_features(data)::Union{Nothing,TDROutputFeaturesSettings}
    isnothing(data) && return nothing
    data isa AbstractDict || throw(ArgumentError("TDR `output_based_features` must be an object."))
    weight = get(data, "weight", nothing)
    weight isa Real && isfinite(weight) && 0.0 < weight < 1.0 || throw(ArgumentError(
        "TDR `output_based_features.weight` must be a finite number strictly between zero and one.",
    ))
    features_data = get(data, "features", nothing)
    features_data isa AbstractVector && !isempty(features_data) || throw(ArgumentError(
        "TDR `output_based_features.features` must be a non-empty array.",
    ))
    subperiod_runs = load_tdr_subperiod_run_settings(get(data, "subperiod_runs", Dict{String,Any}()))
    save_features = get(data, "save_features", false)
    reuse_saved_features = get(data, "reuse_saved_features", false)
    save_features isa Bool || throw(ArgumentError("TDR `output_based_features.save_features` must be a boolean."))
    reuse_saved_features isa Bool || throw(ArgumentError("TDR `output_based_features.reuse_saved_features` must be a boolean."))
    return TDROutputFeaturesSettings(
        weight=Float64(weight),
        features=TDROutputFeatureSpec[tdr_output_feature_spec(feature) for feature in features_data],
        subperiod_runs=subperiod_runs,
        save_features=save_features,
        reuse_saved_features=reuse_saved_features,
    )
end

function load_tdr_subperiod_run_settings(data)::TDRSubperiodRunSettings
    data isa AbstractDict || throw(ArgumentError("TDR `output_based_features.subperiod_runs` must be an object."))
    distributed = get(data, "distributed", false)
    workers = get(data, "workers", 1)
    include_policy_constraints = get(data, "include_policy_constraints", true)
    save_subperiod_inputs = get(data, "save_subperiod_inputs", false)
    save_subperiod_results = get(data, "save_subperiod_results", false)
    distributed isa Bool || throw(ArgumentError("TDR `subperiod_runs.distributed` must be a boolean."))
    workers isa Integer && workers > 0 || throw(ArgumentError("TDR `subperiod_runs.workers` must be a positive integer."))
    include_policy_constraints isa Bool || throw(ArgumentError("TDR `subperiod_runs.include_policy_constraints` must be a boolean."))
    save_subperiod_inputs isa Bool || throw(ArgumentError("TDR `subperiod_runs.save_subperiod_inputs` must be a boolean."))
    save_subperiod_results isa Bool || throw(ArgumentError("TDR `subperiod_runs.save_subperiod_results` must be a boolean."))
    !distributed && workers != 1 && throw(ArgumentError(
        "TDR `subperiod_runs.workers` must equal 1 when `distributed` is false.",
    ))
    return TDRSubperiodRunSettings(
        distributed,
        Int(workers),
        include_policy_constraints,
        save_subperiod_inputs,
        save_subperiod_results,
    )
end

function tdr_output_feature_spec(data::AbstractDict)::TDROutputFeatureSpec
    provider = get(data, "provider", nothing)
    provider isa AbstractString && !isempty(provider) || throw(ArgumentError(
        "Each output-based TDR feature must define a non-empty string `provider`.",
    ))
    id = get(data, "id", nothing)
    asset = get(data, "asset", nothing)
    commodity = get(data, "commodity", nothing)
    all(value -> isnothing(value) || value isa AbstractString, (id, asset, commodity)) || throw(ArgumentError(
        "Output-based TDR feature `id`, `asset`, and `commodity` must be strings when supplied.",
    ))
    weight = get(data, "weight", 1.0)
    weight isa Real && isfinite(weight) && weight > 0 || throw(ArgumentError(
        "Output-based TDR feature `weight` must be a finite positive number.",
    ))
    return TDROutputFeatureSpec(
        id=isnothing(id) ? nothing : String(id),
        provider=String(provider),
        asset=isnothing(asset) ? nothing : String(asset),
        commodity=isnothing(commodity) ? nothing : String(commodity),
        user_weight=Float64(weight),
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
    aggregation in (:integral, :peak) ||
        throw(ArgumentError("Extreme-period `aggregation` must be `integral` or `peak`."))
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
    restarts, verbose = tdr_common_method_settings(settings_data)
    return tdr_method_settings(Val(Symbol(method_data["name"])), settings_data, restarts, verbose)
end

function tdr_common_method_settings(settings_data::AbstractDict)
    restarts = get(settings_data, "restarts", 0)
    restarts isa Integer && restarts >= 0 ||
        throw(ArgumentError("TDR method setting `restarts` must be a non-negative integer."))
    verbose = get(settings_data, "v", false)
    verbose isa Bool || throw(ArgumentError("TDR method setting `v` must be a boolean."))
    return Int(restarts), verbose
end

function tdr_method_integer(
    settings_data::AbstractDict,
    key::String,
    default::Int;
    minimum::Int,
)
    value = get(settings_data, key, default)
    value isa Integer && value >= minimum ||
        throw(ArgumentError("TDR method setting `$key` must be an integer no smaller than $minimum."))
    return Int(value)
end

function tdr_method_float(
    settings_data::AbstractDict,
    key::String,
    default::Float64;
    minimum::Float64,
)
    value = get(settings_data, key, default)
    value isa Real && isfinite(value) && value >= minimum ||
        throw(ArgumentError("TDR method setting `$key` must be a finite number no smaller than $minimum."))
    return Float64(value)
end

function tdr_autoencoder_settings(settings_data::AbstractDict)
    return (
        kernel_size=tdr_method_integer(settings_data, "kernel_size", 3; minimum=1),
        stride=tdr_method_integer(settings_data, "stride", 1; minimum=1),
        epochs=tdr_method_integer(settings_data, "epochs", 50; minimum=1),
        min_err_diff=tdr_method_float(settings_data, "min_err_diff", 1e-4; minimum=0.0),
        patience=tdr_method_integer(settings_data, "patience", 10; minimum=1),
        warmup=tdr_method_integer(settings_data, "warmup", 5; minimum=0),
        n_filters=tdr_method_integer(settings_data, "n_filters", 8; minimum=1),
        latent_dim=tdr_method_integer(settings_data, "latent_dim", 4; minimum=1),
    )
end
