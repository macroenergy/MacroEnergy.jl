abstract type AbstractTDRMethodSettings end

struct TDRExtremePeriodSpec
    feature::TDRFeatureSpec
    aggregation::Symbol
    select::Symbol

    function TDRExtremePeriodSpec(; feature::TDRFeatureSpec, aggregation::Symbol, select::Symbol)
        aggregation in (:integral, :peak) ||
            throw(ArgumentError("Extreme-period `aggregation` must be `integral` or `peak`."))
        select in (:max, :min) ||
            throw(ArgumentError("Extreme-period `select` must be `max` or `min`."))
        new(feature, aggregation, select)
    end
end

"""
Validated configuration for one System's time-domain reduction.

`load_time_domain_reduction_settings` and `load_tdr_settings_by_system` build
this type from JSON settings after applying defaults and validating the selected
clustering method, features, extreme periods, and optional output features.
"""
struct TDRSettings
    timesteps_per_representative_period::Int
    representative_periods::Int
    method_settings::AbstractTDRMethodSettings
    scaling::Symbol
    all_features::Vector{TDRFeatureSpec}
    features::Vector{TDRFeatureSpec}
    excluded_features::Vector{TDRFeatureSpec}
    extreme_periods::Vector{TDRExtremePeriodSpec}
    output_features::Union{Nothing,TDROutputFeaturesSettings}

    function TDRSettings(; timesteps_per_representative_period::Integer,
        representative_periods::Integer, method_settings::AbstractTDRMethodSettings,
        scaling::Symbol, all_features::Vector{TDRFeatureSpec}, features::Vector{TDRFeatureSpec},
        excluded_features::Vector{TDRFeatureSpec}, extreme_periods::Vector{TDRExtremePeriodSpec},
        output_features::Union{Nothing,TDROutputFeaturesSettings}=nothing)
        timesteps_per_representative_period > 0 || throw(ArgumentError(
            "`timesteps_per_representative_period` must be a positive integer.",
        ))
        representative_periods > 0 || throw(ArgumentError("`representative_periods` must be a positive integer."))
        scaling in (:standardize, :normalize) ||
            throw(ArgumentError("TDR `scaling` must be `standardize` or `normalize`."))
        new(
            Int(timesteps_per_representative_period), Int(representative_periods), method_settings,
            scaling, all_features, features, excluded_features, extreme_periods, output_features,
        )
    end
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

function tdr_method_setting_names(method_name::String)
    names = Set(("restarts", "verbose"))
    if method_name in ("autoencoder_sequential", "autoencoder_simultaneous")
        union!(names, (
            "kernel_size", "stride", "epochs", "min_err_diff", "patience", "warmup",
            "n_filters", "latent_dim",
        ))
    end
    if method_name == "autoencoder_simultaneous"
        push!(names, "lambda")
    elseif !(method_name in ("kmeans", "kmedoids", "autoencoder_sequential"))
        throw(ArgumentError(
            "TDR `method.name` must be `kmeans`, `kmedoids`, `autoencoder_sequential`, or `autoencoder_simultaneous`; received `$method_name`.",
        ))
    end
    return names
end

function tdr_setting_data(data, allowed_keys, setting_name::String)
    data isa AbstractDict || throw(ArgumentError("TDR `$setting_name` must be an object."))
    normalized_data = Dict{String,Any}(String(key) => value for (key, value) in pairs(data))
    unknown_keys = setdiff(keys(normalized_data), allowed_keys)
    isempty(unknown_keys) || throw(ArgumentError(
        "TDR `$setting_name` contains unknown setting$(length(unknown_keys) == 1 ? "" : "s"): $(join(sort!(collect(unknown_keys)), ", ")).",
    ))
    return normalized_data
end

function tdr_merge_settings(data, defaults::Dict{String,Any}, setting_name::String)
    normalized_data = tdr_setting_data(data, keys(defaults), setting_name)
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
    return load_tdr_settings_data(mutable_json_data(read_json(path)))
end

function load_tdr_settings_data(raw_data)::TDRSettings
    data = tdr_merge_settings(raw_data, default_tdr_settings(), "settings")
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

"""Resolve JSON configuration to one independent TDR settings object per System."""
function load_tdr_settings_by_system(path::AbstractString, number_of_systems::Int)
    isfile(path) || throw(ArgumentError("TDR settings file does not exist: $(abspath(path))"))
    number_of_systems > 0 || throw(ArgumentError("TDR requires at least one System."))
    data = mutable_json_data(read_json(path))
    if haskey(data, "systems")
        keys_without_systems = setdiff(String.(keys(data)), ["systems"])
        isempty(keys_without_systems) || throw(ArgumentError(
            "TDR `systems` cannot be combined with top-level settings: $(join(sort!(keys_without_systems), ", ")).",
        ))
        configurations = data["systems"]
        configurations isa AbstractVector || throw(ArgumentError("TDR `systems` must be an array."))
        length(configurations) == number_of_systems || throw(ArgumentError(
            "TDR `systems` has $(length(configurations)) entries, but the Case has $number_of_systems Systems.",
        ))
        return TDRSettings[load_tdr_settings_data(configuration) for configuration in configurations]
    end
    representative_periods = get(data, "representative_periods", nothing)
    if representative_periods isa AbstractVector
        length(representative_periods) == number_of_systems || throw(ArgumentError(
            "TDR `representative_periods` has $(length(representative_periods)) entries, but the Case has $number_of_systems Systems.",
        ))
        return TDRSettings[
            load_tdr_settings_data(recursive_merge(data, Dict("representative_periods" => periods)))
            for periods in representative_periods
        ]
    end
    settings = load_tdr_settings_data(data)
    return [deepcopy(settings) for _ in 1:number_of_systems]
end

function load_tdr_output_features(data)::Union{Nothing,TDROutputFeaturesSettings}
    isnothing(data) && return nothing
    data = tdr_setting_data(data, (
        "weight", "features", "subperiod_runs", "save_features", "reuse_saved_features",
    ), "output_based_features")
    weight = get(data, "weight", nothing)
    weight isa Real && isfinite(weight) && 0.0 < weight < 1.0 || throw(ArgumentError(
        "TDR `output_based_features.weight` must be a finite number strictly between zero and one.",
    ))
    features_data = get(data, "features", nothing)
    features_data isa AbstractVector && !isempty(features_data) || throw(ArgumentError(
        "TDR `output_based_features.features` must be a non-empty array.",
    ))
    keyword_arguments = Dict{Symbol,Any}(
        :weight => Float64(weight),
        :features => TDROutputFeatureSpec[tdr_output_feature_spec(feature) for feature in features_data],
    )
    haskey(data, "subperiod_runs") &&
        (keyword_arguments[:subperiod_runs] = load_tdr_subperiod_run_settings(data["subperiod_runs"]))
    for key in ("save_features", "reuse_saved_features")
        haskey(data, key) || continue
        data[key] isa Bool || throw(ArgumentError("TDR `output_based_features.$key` must be a boolean."))
        keyword_arguments[Symbol(key)] = data[key]
    end
    return TDROutputFeaturesSettings(; keyword_arguments...)
end

function load_tdr_subperiod_run_settings(data)::TDRSubperiodRunSettings
    data = tdr_setting_data(data, (
        "distributed", "workers", "include_policy_constraints", "save_subperiod_inputs",
        "save_subperiod_results",
    ), "output_based_features.subperiod_runs")
    for key in ("distributed", "include_policy_constraints", "save_subperiod_inputs", "save_subperiod_results")
        haskey(data, key) || continue
        data[key] isa Bool || throw(ArgumentError("TDR `subperiod_runs.$key` must be a boolean."))
    end
    haskey(data, "workers") && !(data["workers"] isa Integer) &&
        throw(ArgumentError("TDR `subperiod_runs.workers` must be a positive integer."))
    keyword_arguments = Dict{Symbol,Any}(Symbol(key) => value for (key, value) in pairs(data))
    return TDRSubperiodRunSettings(; keyword_arguments...)
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
    settings_data = method_data["settings"]
    settings_data isa AbstractDict || throw(ArgumentError("TDR `method.settings` must be an object."))
    keyword_arguments = Dict{Symbol,Any}(Symbol(key) => value for (key, value) in pairs(settings_data))
    unknown_keys = setdiff(String.(keys(keyword_arguments)), tdr_method_setting_names(String(method_name)))
    isempty(unknown_keys) || throw(ArgumentError(
        "TDR `method.settings` contains unknown setting$(length(unknown_keys) == 1 ? "" : "s"): $(join(sort!(unknown_keys), ", ")).",
    ))
    return tdr_method_settings(Val(Symbol(method_name)), keyword_arguments)
end

function tdr_validated_autoencoder_settings(; kernel_size::Integer=3, stride::Integer=1,
    epochs::Integer=50, min_err_diff::Real=1e-4, patience::Integer=10, warmup::Integer=5,
    n_filters::Integer=8, latent_dim::Integer=4)
    kernel_size >= 1 || throw(ArgumentError("TDR `kernel_size` must be at least 1."))
    stride >= 1 || throw(ArgumentError("TDR `stride` must be at least 1."))
    epochs >= 1 || throw(ArgumentError("TDR `epochs` must be at least 1."))
    isfinite(min_err_diff) && min_err_diff >= 0 ||
        throw(ArgumentError("TDR `min_err_diff` must be finite and non-negative."))
    patience >= 1 || throw(ArgumentError("TDR `patience` must be at least 1."))
    warmup >= 0 || throw(ArgumentError("TDR `warmup` must be non-negative."))
    n_filters >= 1 || throw(ArgumentError("TDR `n_filters` must be at least 1."))
    latent_dim >= 1 || throw(ArgumentError("TDR `latent_dim` must be at least 1."))
    return (
        kernel_size=Int(kernel_size), stride=Int(stride), epochs=Int(epochs),
        min_err_diff=Float64(min_err_diff), patience=Int(patience), warmup=Int(warmup),
        n_filters=Int(n_filters), latent_dim=Int(latent_dim),
    )
end
