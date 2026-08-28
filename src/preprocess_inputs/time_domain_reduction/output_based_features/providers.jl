tdr_flow_provider(args...; kwargs...) = getfield(@__MODULE__, :get_optimal_flow)(args...; kwargs...)
tdr_storage_level_provider(args...; kwargs...) = getfield(@__MODULE__, :get_optimal_storage_level)(args...; kwargs...)

const TDR_OUTPUT_PROVIDERS = Dict{String,Function}(
    "flow" => tdr_flow_provider,
    "storage_level" => tdr_storage_level_provider,
)

function tdr_output_provider(name::String)::Function
    haskey(TDR_OUTPUT_PROVIDERS, name) && return TDR_OUTPUT_PROVIDERS[name]
    symbol = Symbol(name)
    isdefined(@__MODULE__, symbol) || throw(ArgumentError(
        "Unknown output-based TDR provider `$name`. Register it in TDR_OUTPUT_PROVIDERS or define a function with that name in MacroEnergy.",
    ))
    provider = getfield(@__MODULE__, symbol)
    provider isa Function || throw(ArgumentError("Output-based TDR provider `$name` is not a function."))
    return provider
end

function tdr_output_feature_specificity(feature::TDROutputFeatureSpec)
    return count(value -> !isnothing(value), (feature.id, feature.asset, feature.commodity))
end

function tdr_selected_output_feature(
    candidates::Vector{TDROutputFeatureSpec},
    provider::String,
)
    matches = filter(feature -> feature.provider == provider, candidates)
    isempty(matches) && return nothing
    specificity = tdr_output_feature_specificity.(matches)
    best = maximum(specificity)
    matches = matches[specificity .== best]
    length(matches) == 1 || throw(ArgumentError(
        "Output-based TDR feature selection for provider `$provider` is ambiguous. Add an `id`, `asset`, or `commodity` selector.",
    ))
    return only(matches)
end

function tdr_output_values(data::DataFrame, full_length::Int, description::String)
    :time in propertynames(data) || throw(ArgumentError("Output provider `$description` must return a DataFrame with a `time` column."))
    :component_id in propertynames(data) || throw(ArgumentError("Output provider `$description` must return a DataFrame with a `component_id` column."))
    :value in propertynames(data) || throw(ArgumentError("Output provider `$description` must return a DataFrame with a `value` column."))
    wide = reshape_wide(data, :time, :component_id, :value)
    sort!(wide, :time)
    nrow(wide) == full_length || throw(ArgumentError(
        "Output provider `$description` returned $(nrow(wide)) time steps; expected $full_length.",
    ))
    return wide
end

function tdr_output_sources(
    case_root::String,
    settings::TDROutputFeaturesSettings,
    full_length::Int;
    run_case_kwargs::NamedTuple=NamedTuple(),
)
    case = tdr_output_case(case_root; run_case_kwargs...)
    length(case.systems) == 1 || throw(ArgumentError(
        "Output-based TDR currently supports one model period. Multi-period output features will be grouped by time data in a later extension.",
    ))
    system = only(case.systems)
    candidates = Dict{String,Vector{Tuple{TDROutputFeatureSpec,Vector{Float64}}}}()
    for feature in settings.features
        provider = tdr_output_provider(feature.provider)
        data = provider(system, 1.0; commodity=feature.commodity, asset_type=feature.asset)
        isempty(data) && continue
        wide = tdr_output_values(data, full_length, feature.provider)
        for column in names(wide, Not(:time))
            !isnothing(feature.id) && String(column) != feature.id && continue
            key = "output:" * feature.provider * ":" * String(column)
            push!(get!(candidates, key, Tuple{TDROutputFeatureSpec,Vector{Float64}}[]),
                (feature, Float64.(wide[!, column])))
        end
    end
    isempty(candidates) && throw(ArgumentError("No output-based TDR features produced time-series values."))
    sources = TimeSeriesSource[]
    for (key, matches) in sort!(collect(candidates); by=first)
        provider = split(key, ":"; limit=3)[2]
        feature = tdr_selected_output_feature(first.(matches), provider)
        values = first(matches)[2]
        all(values == match[2] for match in matches) || throw(ArgumentError(
            "Output provider `$provider` returned inconsistent values for `$key` under overlapping feature selectors.",
        ))
        reference = (
            json_file=nothing,
            input_path=Any[],
            feature_id=feature.id,
            field=feature.provider,
            asset=feature.asset,
            commodity=feature.commodity,
            user_weight=feature.user_weight,
            include_in_clustering=true,
        )
        push!(sources, TimeSeriesSource(key, nothing, nothing, nothing, Any[], values, 1,
            [reference], 1, feature.user_weight, feature.user_weight, true))
    end
    return sources
end

function tdr_output_case(
    case_root::String;
    lazy_load::Bool=true,
    optimizer::DataType=HiGHS.Optimizer,
    optimizer_env::Any=nothing,
    optimizer_attributes::Tuple=(
        "solver" => "ipm",
        "run_crossover" => "off",
        "ipm_optimality_tolerance" => 1e-3,
    ),
)
    setup_user_additions(case_root)
    load_user_additions(case_root)
    refresh_user_type_registries!()
    case = load_case(case_root; lazy_load)
    solution_algorithm(case) isa Monolithic || throw(ArgumentError(
        "Output-based TDR currently supports the Monolithic solution algorithm.",
    ))
    scaling = parameter_scaling_factor(get_settings(case))
    try
        solution = solve_case(case, create_optimizer(optimizer, optimizer_env, optimizer_attributes))
        postprocess!(case, solution)
        return case
    finally
        unscale!(case, scaling)
    end
end
