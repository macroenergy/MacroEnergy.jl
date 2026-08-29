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

"""Return the complete TDR JSON settings schema and its defaults."""
function default_tdr_settings()
    return Dict{String,Any}(
        "timesteps_per_representative_period" => nothing,
        "representative_periods" => nothing,
        "method" => nothing,
        "scaling" => nothing,
        "features" => Any[],
        "exclude" => Any[],
        "extreme_periods" => Any[],
        "output_based_features" => nothing,
    )
end

function default_tdr_method_configuration()
    return Dict{String,Any}(
        "name" => nothing,
        "settings" => Dict{String,Any}(),
    )
end

function default_tdr_method_settings(method_name::String)
    defaults = Dict{String,Any}(
        "restarts" => 0,
        "v" => false,
    )
    if method_name in ("autoencoder_sequential", "autoencoder_simultaneous")
        merge!(defaults, Dict(
            "kernel_size" => 3,
            "stride" => 1,
            "epochs" => 50,
            "min_err_diff" => 1e-4,
            "patience" => 10,
            "warmup" => 5,
            "n_filters" => 8,
            "latent_dim" => 4,
        ))
    end
    if method_name == "autoencoder_simultaneous"
        defaults["lambda"] = 0.1
    elseif !(method_name in ("kmeans", "kmedoids", "autoencoder_sequential"))
        throw(ArgumentError(
            "TDR `method.name` must be `kmeans`, `kmedoids`, `autoencoder_sequential`, or `autoencoder_simultaneous`; received `$method_name`.",
        ))
    end
    return defaults
end

function default_tdr_output_feature_settings()
    return Dict{String,Any}(
        "weight" => nothing,
        "features" => nothing,
        "subperiod_runs" => Dict{String,Any}(),
        "save_features" => false,
        "reuse_saved_features" => false,
    )
end

function default_tdr_subperiod_run_settings()
    return Dict{String,Any}(
        "distributed" => false,
        "workers" => 1,
        "include_policy_constraints" => true,
        "save_subperiod_inputs" => false,
        "save_subperiod_results" => false,
    )
end

function tdr_merge_settings(data, defaults::Dict{String,Any}, setting_name::String)
    data isa AbstractDict || throw(ArgumentError("TDR `$setting_name` must be an object."))
    normalized_data = Dict{String,Any}(String(key) => value for (key, value) in pairs(data))
    unknown_keys = setdiff(keys(normalized_data), keys(defaults))
    isempty(unknown_keys) || throw(ArgumentError(
        "TDR `$setting_name` contains unknown setting$(length(unknown_keys) == 1 ? "" : "s"): $(join(sort!(collect(unknown_keys)), ", ")).",
    ))
    return recursive_merge(defaults, normalized_data)
end

function tdr_required_setting(data::Dict{String,Any}, key::String, setting_name::String)
    isnothing(data[key]) && throw(ArgumentError("TDR `$setting_name` is missing `$key`."))
    return data[key]
end

"""
    load_time_domain_reduction_settings(path) -> TDRSettings

Load and validate the JSON settings used by [`preprocess_inputs`](@ref).
"""
function load_time_domain_reduction_settings(path::AbstractString)::TDRSettings
    isfile(path) || throw(ArgumentError("TDR settings file does not exist: $(abspath(path))"))
    data = tdr_merge_settings(mutable_json_data(read_json(path)), default_tdr_settings(), "settings")
    period_length = tdr_required_setting(data, "timesteps_per_representative_period", "settings")
    n_periods = tdr_required_setting(data, "representative_periods", "settings")
    period_length isa Integer && period_length > 0 || throw(ArgumentError("`timesteps_per_representative_period` must be a positive integer."))
    n_periods isa Integer && n_periods > 0 || throw(ArgumentError("`representative_periods` must be a positive integer."))
    method_settings = load_tdr_method_settings(tdr_required_setting(data, "method", "settings"))
    scaling_data = tdr_required_setting(data, "scaling", "settings")
    scaling_data isa AbstractString || throw(ArgumentError("TDR `scaling` must be a string."))
    scaling = Symbol(scaling_data)
    scaling in (:standardize, :normalize) || throw(ArgumentError("TDR `scaling` must be `standardize` or `normalize`."))
    data["features"] isa AbstractVector || throw(ArgumentError("TDR `features` must be an array."))
    data["exclude"] isa AbstractVector || throw(ArgumentError("TDR `exclude` must be an array."))
    user_features = TDRFeatureSpec[tdr_feature_spec(feature) for feature in data["features"]]
    exclusions = TDRFeatureSpec[tdr_feature_spec(selector; require_field=false) for selector in data["exclude"]]
    all_features = tdr_merge_features(user_features)
    active_features = [
        feature for feature in all_features if !any(exclusion -> tdr_feature_matches_selector(feature, exclusion), exclusions)
    ]
    extreme_periods_data = data["extreme_periods"]
    extreme_periods_data isa AbstractVector ||
        throw(ArgumentError("TDR `extreme_periods` must be an array."))
    extreme_periods = TDRExtremePeriodSpec[
        tdr_extreme_period_spec(specification) for specification in extreme_periods_data
    ]
    output_features = load_tdr_output_features(data["output_based_features"])
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
    data = tdr_merge_settings(data, default_tdr_output_feature_settings(), "output_based_features")
    weight = data["weight"]
    weight isa Real && isfinite(weight) && 0.0 < weight < 1.0 || throw(ArgumentError(
        "TDR `output_based_features.weight` must be a finite number strictly between zero and one.",
    ))
    features_data = data["features"]
    features_data isa AbstractVector && !isempty(features_data) || throw(ArgumentError(
        "TDR `output_based_features.features` must be a non-empty array.",
    ))
    subperiod_runs = load_tdr_subperiod_run_settings(data["subperiod_runs"])
    save_features = data["save_features"]
    reuse_saved_features = data["reuse_saved_features"]
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
    data = tdr_merge_settings(data, default_tdr_subperiod_run_settings(), "output_based_features.subperiod_runs")
    distributed = data["distributed"]
    workers = data["workers"]
    include_policy_constraints = data["include_policy_constraints"]
    save_subperiod_inputs = data["save_subperiod_inputs"]
    save_subperiod_results = data["save_subperiod_results"]
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
    method_data = tdr_merge_settings(method_data, default_tdr_method_configuration(), "method")
    method_name = tdr_required_setting(method_data, "name", "method")
    method_name isa AbstractString || throw(ArgumentError("TDR method `name` must be a string."))
    settings_data = tdr_merge_settings(
        method_data["settings"],
        default_tdr_method_settings(String(method_name)),
        "method.settings",
    )
    restarts, verbose = tdr_common_method_settings(settings_data)
    return tdr_method_settings(Val(Symbol(method_name)), settings_data, restarts, verbose)
end

function tdr_common_method_settings(settings_data::AbstractDict)
    restarts = settings_data["restarts"]
    restarts isa Integer && restarts >= 0 ||
        throw(ArgumentError("TDR method setting `restarts` must be a non-negative integer."))
    verbose = settings_data["v"]
    verbose isa Bool || throw(ArgumentError("TDR method setting `v` must be a boolean."))
    return Int(restarts), verbose
end

function tdr_method_integer(
    settings_data::AbstractDict,
    key::String,
    ;
    minimum::Int,
)
    value = settings_data[key]
    value isa Integer && value >= minimum ||
        throw(ArgumentError("TDR method setting `$key` must be an integer no smaller than $minimum."))
    return Int(value)
end

function tdr_method_float(
    settings_data::AbstractDict,
    key::String,
    ;
    minimum::Float64,
)
    value = settings_data[key]
    value isa Real && isfinite(value) && value >= minimum ||
        throw(ArgumentError("TDR method setting `$key` must be a finite number no smaller than $minimum."))
    return Float64(value)
end

function tdr_autoencoder_settings(settings_data::AbstractDict)
    return (
        kernel_size=tdr_method_integer(settings_data, "kernel_size"; minimum=1),
        stride=tdr_method_integer(settings_data, "stride"; minimum=1),
        epochs=tdr_method_integer(settings_data, "epochs"; minimum=1),
        min_err_diff=tdr_method_float(settings_data, "min_err_diff"; minimum=0.0),
        patience=tdr_method_integer(settings_data, "patience"; minimum=1),
        warmup=tdr_method_integer(settings_data, "warmup"; minimum=0),
        n_filters=tdr_method_integer(settings_data, "n_filters"; minimum=1),
        latent_dim=tdr_method_integer(settings_data, "latent_dim"; minimum=1),
    )
end
