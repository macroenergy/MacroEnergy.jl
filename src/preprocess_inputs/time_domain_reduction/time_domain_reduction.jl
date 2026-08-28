include("tdr_utilities.jl")
include("tdr_settings.jl")
include("tdr_inputs.jl")
include("tdr_extreme_periods.jl")
include("tdr_methods/tdr_methods.jl")
include("tdr_clustering.jl")
include("output_based_features/output_based_features.jl")
include("tdr_outputs.jl")
include("tdr_log.jl")

"""
    time_domain_reduction(case_path, settings)

Apply an input-only time-domain reduction in an already copied case directory.
`settings` may be a [`TDRSettings`](@ref) or a path to its JSON file.
"""
function time_domain_reduction(
    case_path::AbstractString,
    settings;
    output_feature_run_kwargs::NamedTuple=NamedTuple(),
)::Nothing
    parsed_settings = settings isa TDRSettings ? settings : load_time_domain_reduction_settings(settings)
    tdr_time_domain_reduction(abspath(case_path), parsed_settings; output_feature_run_kwargs)
    return nothing
end

function tdr_time_domain_reduction(
    case_path::AbstractString,
    parsed_settings::TDRSettings;
    source_case_path::AbstractString=case_path,
    output_feature_run_kwargs::NamedTuple=NamedTuple(),
)::Nothing
    case_root = abspath(case_path)
    isdir(case_root) || throw(ArgumentError("Case directory does not exist: $case_root"))

    sources, clustering_sources, full_length, time_data_path, time_data, trailing_hours =
        tdr_sources(case_root, parsed_settings)
    if !isnothing(parsed_settings.output_features)
        input_sources = copy(clustering_sources)
        output_sources = tdr_output_sources(
            case_root,
            parsed_settings.output_features,
            full_length;
            run_case_kwargs=output_feature_run_kwargs,
        )
        append!(sources, output_sources)
        append!(clustering_sources, output_sources)
        tdr_set_clustering_weights!(input_sources, output_sources, parsed_settings.output_features.weight)
    end
    extreme_selections = tdr_extreme_period_selections(
        sources,
        parsed_settings.timesteps_per_representative_period,
        parsed_settings,
        case_root,
    )
    extreme_periods = sort!(unique(Int[selection.period for selection in extreme_selections]))
    representatives, period_map = tdr_cluster(
        clustering_sources,
        full_length,
        parsed_settings;
        extreme_periods,
    )
    row_indices = tdr_row_indices(representatives, parsed_settings.timesteps_per_representative_period)
    tdr_write_reduced_sources!(sources, row_indices)
    clear_csv_cache!()
    map_path, output_period_map = tdr_write_time_data!(
        time_data_path,
        case_root,
        time_data,
        parsed_settings,
        representatives,
        period_map,
    )
    provenance = Dict(
        "source_case_path" => abspath(source_case_path),
        "settings" => Dict(
            "timesteps_per_representative_period" => parsed_settings.timesteps_per_representative_period,
            "representative_periods" => parsed_settings.representative_periods,
            "method" => String(tdr_method_name(parsed_settings.method_settings)),
            "method_settings" => tdr_method_settings_data(parsed_settings.method_settings),
            "scaling" => String(parsed_settings.scaling),
            "extreme_periods" => tdr_extreme_period_specification_data.(parsed_settings.extreme_periods),
            "output_based_features" => isnothing(parsed_settings.output_features) ? nothing : Dict(
                "weight" => parsed_settings.output_features.weight,
                "features" => [
                    Dict(
                        "provider" => feature.provider,
                        "id" => feature.id,
                        "asset" => feature.asset,
                        "commodity" => feature.commodity,
                        "weight" => feature.user_weight,
                    ) for feature in parsed_settings.output_features.features
                ],
            ),
        ),
        "representative_periods" => representatives,
        "forced_extreme_periods" => extreme_periods,
        "trailing_source_hours_excluded_from_tdr" => trailing_hours,
        "period_map_path" => relpath(map_path, case_root),
    )
    write_json(joinpath(case_root, "time_domain_reduction_provenance.json"), provenance)
    tdr_write_preprocess_log!(
        case_root,
        sources,
        clustering_sources,
        full_length,
        parsed_settings,
        extreme_selections,
        representatives,
        output_period_map,
        map_path,
        trailing_hours,
    )
    return nothing
end
