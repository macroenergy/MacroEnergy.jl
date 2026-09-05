
"""Provide optimal operational flows in the output-feature provider format."""
tdr_flow_provider(args...; kwargs...) = getfield(@__MODULE__, :get_optimal_flow)(args...; kwargs...)

"""Provide optimal storage levels in the output-feature provider format."""
tdr_storage_level_provider(args...; kwargs...) = getfield(@__MODULE__, :get_optimal_storage_level)(args...; kwargs...)

"""
Built-in output-feature providers.

Each provider receives a System and the standard output accessor keyword
arguments, and must return a table with `time`, `component_id`, and `value`
columns.

To add an official provider:

1. Define a `tdr_<name>_provider` function in this file. It must accept a
   System, the standard output scale positional argument, and `commodity` and
   `asset_type` keyword arguments.
2. Add `"<name>" => tdr_<name>_provider` to `TDR_OUTPUT_PROVIDERS` below.
3. Add focused provider-contract coverage and document the provider in the
   time-domain-reduction manual.

Case-specific providers defined through user additions are intentionally not
supported yet; they will be added in a future feature.
"""
const TDR_OUTPUT_PROVIDERS = Dict{String,Function}(
    "flow" => tdr_flow_provider,
    "storage_level" => tdr_storage_level_provider,
)

function tdr_output_provider(name::String)::Function
    haskey(TDR_OUTPUT_PROVIDERS, name) && return TDR_OUTPUT_PROVIDERS[name]
    available = join(sort!(collect(keys(TDR_OUTPUT_PROVIDERS))), "`, `")
    throw(ArgumentError("Unknown output-based TDR provider `$name`. Available providers are `$available`."))
end

tdr_output_feature_specificity(feature::TDROutputFeatureSpec) =
    count(value -> !isnothing(value), (feature.id, feature.asset, feature.commodity))

function tdr_selected_output_feature(candidates::Vector{TDROutputFeatureSpec}, provider::AbstractString)
    matches = filter(feature -> feature.provider == provider, candidates)
    isempty(matches) && return nothing
    specificity = tdr_output_feature_specificity.(matches)
    matches = matches[specificity .== maximum(specificity)]
    length(matches) == 1 || throw(ArgumentError(
        "Output-based TDR feature selection for provider `$provider` is ambiguous. Add an `id`, `asset`, or `commodity` selector.",
    ))
    return only(matches)
end

function tdr_output_values(data::DataFrame, period_length::Int, description::String)
    required = (:time, :component_id, :value)
    all(column -> column in propertynames(data), required) || throw(ArgumentError(
        "Output provider `$description` must return `time`, `component_id`, and `value` columns.",
    ))
    wide = reshape_wide(data, :time, :component_id, :value)
    sort!(wide, :time)
    nrow(wide) == period_length || throw(ArgumentError(
        "Output provider `$description` returned $(nrow(wide)) time steps; expected $period_length.",
    ))
    return wide
end

function tdr_subperiod_output_data(system, settings::TDROutputFeaturesSettings, period_length::Int)
    outputs = Dict{String,Vector{Tuple{TDROutputFeatureSpec,Vector{Float64}}}}()
    for feature in settings.features
        data = tdr_output_provider(feature.provider)(
            system,
            1.0;
            commodity=feature.commodity,
            asset_type=feature.asset,
        )
        isempty(data) && continue
        wide = tdr_output_values(data, period_length, feature.provider)
        for column in names(wide, Not(:time))
            !isnothing(feature.id) && String(column) != feature.id && continue
            key = "output:" * feature.provider * ":" * String(column)
            push!(get!(outputs, key, Tuple{TDROutputFeatureSpec,Vector{Float64}}[]),
                (feature, Float64.(wide[!, column])))
        end
    end
    return outputs
end
