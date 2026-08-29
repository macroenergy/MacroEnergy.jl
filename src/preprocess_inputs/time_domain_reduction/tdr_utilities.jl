struct TDRFeatureSpec
    id::Union{Nothing,String}
    file::Union{Nothing,String}
    asset::Union{Nothing,String}
    commodity::Union{Nothing,String}
    field::String
    user_weight::Float64
    has_user_weight::Bool

    function TDRFeatureSpec(; id=nothing, file=nothing, asset=nothing, commodity=nothing,
        field::AbstractString="", user_weight::Real=1.0, has_user_weight::Bool=false)
        all(value -> isnothing(value) || value isa AbstractString, (id, file, asset, commodity)) ||
            throw(ArgumentError("TDR feature `id`, `file`, `asset`, and `commodity` must be strings when supplied."))
        isfinite(user_weight) && user_weight > 0 ||
            throw(ArgumentError("TDR feature `weight` must be a finite positive number."))
        new(
            isnothing(id) ? nothing : String(id),
            isnothing(file) ? nothing : String(file),
            isnothing(asset) ? nothing : String(asset),
            isnothing(commodity) ? nothing : String(commodity),
            String(field),
            Float64(user_weight),
            has_user_weight,
        )
    end
end

"""A resolved physical time series and all input locations which consume it."""
mutable struct TimeSeriesSource
    key::String
    csv_path::Union{Nothing,String}
    header::Union{Nothing,Symbol}
    inline_file::Union{Nothing,String}
    inline_path::Vector{Any}
    values::Vector{Float64}
    timestep_hours::Int
    references::Vector{NamedTuple}
    occurrences::Int
    user_weight::Float64
    weight::Float64
    include_in_clustering::Bool
end

"""A requested result accessor used as an additional TDR clustering feature."""
struct TDROutputFeatureSpec
    id::Union{Nothing,String}
    provider::String
    asset::Union{Nothing,String}
    commodity::Union{Nothing,String}
    user_weight::Float64

    function TDROutputFeatureSpec(; id=nothing, provider::AbstractString="", asset=nothing,
        commodity=nothing, user_weight::Real=1.0)
        !isempty(provider) || throw(ArgumentError("Each output-based TDR feature must define a non-empty string `provider`."))
        all(value -> isnothing(value) || value isa AbstractString, (id, asset, commodity)) ||
            throw(ArgumentError("Output-based TDR feature `id`, `asset`, and `commodity` must be strings when supplied."))
        isfinite(user_weight) && user_weight > 0 ||
            throw(ArgumentError("Output-based TDR feature `weight` must be a finite positive number."))
        new(
            isnothing(id) ? nothing : String(id),
            String(provider),
            isnothing(asset) ? nothing : String(asset),
            isnothing(commodity) ? nothing : String(commodity),
            Float64(user_weight),
        )
    end
end

struct TDRSubperiodRunSettings
    distributed::Bool
    workers::Int
    include_policy_constraints::Bool
    save_subperiod_inputs::Bool
    save_subperiod_results::Bool

    function TDRSubperiodRunSettings(; distributed::Bool=false, workers::Integer=1,
        include_policy_constraints::Bool=true, save_subperiod_inputs::Bool=false,
        save_subperiod_results::Bool=false)
        workers > 0 || throw(ArgumentError("TDR `subperiod_runs.workers` must be a positive integer."))
        !distributed && workers != 1 && throw(ArgumentError(
            "TDR `subperiod_runs.workers` must equal 1 when `distributed` is false.",
        ))
        new(distributed, Int(workers), include_policy_constraints, save_subperiod_inputs, save_subperiod_results)
    end
end

struct TDROutputFeaturesSettings
    weight::Float64
    features::Vector{TDROutputFeatureSpec}
    subperiod_runs::TDRSubperiodRunSettings
    save_features::Bool
    reuse_saved_features::Bool

    function TDROutputFeaturesSettings(; weight::Real, features::Vector{TDROutputFeatureSpec},
        subperiod_runs::TDRSubperiodRunSettings=TDRSubperiodRunSettings(), save_features::Bool=false,
        reuse_saved_features::Bool=false)
        isfinite(weight) && 0.0 < weight < 1.0 || throw(ArgumentError(
            "TDR `output_based_features.weight` must be strictly between zero and one.",
        ))
        !isempty(features) || throw(ArgumentError("TDR `output_based_features.features` must be non-empty."))
        new(Float64(weight), features, subperiod_runs, save_features, reuse_saved_features)
    end
end

const TDR_DEFAULT_FEATURES = TDRFeatureSpec[
    TDRFeatureSpec(id="availability", field="availability"),
    TDRFeatureSpec(id="demand", field="demand"),
    TDRFeatureSpec(id="supply_price", field="supply.price"),
    TDRFeatureSpec(id="supply_min", field="supply.min"),
    TDRFeatureSpec(id="supply_max", field="supply.max"),
    TDRFeatureSpec(id="loss_fraction", field="loss_fraction"),
]
