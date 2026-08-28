function tdr_source_log_data(source::TimeSeriesSource, case_root::String)
    references = source.references
    location = if !isnothing(source.csv_path)
        Dict(
            "type" => "csv",
            "path" => tdr_relative_path(case_root, source.csv_path),
            "header" => String(source.header),
        )
    else
        Dict(
            "type" => "inline_json",
            "path" => tdr_relative_path(case_root, source.inline_file),
            "input_path" => string.(source.inline_path),
        )
    end
    return Dict(
        "source" => location,
        "feature_ids" => sort!(unique([
            reference.feature_id for reference in references if !isnothing(reference.feature_id)
        ])),
        "fields" => sort!(unique(reference.field for reference in references)),
        "assets" => sort!(unique([
            reference.asset for reference in references if !isnothing(reference.asset)
        ])),
        "commodities" => sort!(unique([
            reference.commodity for reference in references if !isnothing(reference.commodity)
        ])),
        "occurrences" => source.occurrences,
        "user_weight" => source.user_weight,
        "weight" => source.weight,
    )
end

function tdr_representative_period_log_data(
    representative_periods::Vector{Int},
    output_period_map::DataFrame,
)
    representative_data = Dict[]
    for (index, period) in enumerate(representative_periods)
        mapped_periods = Int[
            row.Period_Index for row in eachrow(output_period_map)
            if row.Rep_Period_Index == index
        ]
        push!(representative_data, Dict(
            "representative_period" => period,
            "representative_period_index" => index,
            "total_mapped_periods" => length(mapped_periods),
            "mapped_periods" => mapped_periods,
        ))
    end
    return representative_data
end

function tdr_preprocess_log_data(
    sources::Vector{TimeSeriesSource},
    clustering_sources::Vector{TimeSeriesSource},
    full_length::Int,
    settings::TDRSettings,
    extreme_selections,
    representative_periods::Vector{Int},
    output_period_map::DataFrame,
    map_path::String,
    case_root::String,
    trailing_hours::Int,
)
    forced_periods = sort!(unique(Int[selection.period for selection in extreme_selections]))
    period_length = settings.timesteps_per_representative_period
    clustering_source_data = [
        tdr_source_log_data(source, case_root)
        for source in sort(clustering_sources; by=source -> source.key)
    ]
    return Dict(
        "time_domain_reduction" => Dict(
            "temporal_summary" => Dict(
                "original_hours" => full_length,
                "trailing_source_hours_excluded_from_tdr" => trailing_hours,
                "original_periods" => full_length ÷ period_length,
                "period_map_rows" => nrow(output_period_map),
                "timesteps_per_representative_period" => period_length,
                "representative_periods" => settings.representative_periods,
                "reduced_hours" => settings.representative_periods * period_length,
                "period_map_path" => tdr_relative_path(case_root, map_path),
            ),
            "extreme_periods" => tdr_extreme_period_selection_data.(extreme_selections),
            "clustering" => Dict(
                "method" => String(tdr_method_name(settings.method_settings)),
                "method_settings" => tdr_method_settings_data(settings.method_settings),
                "scaling" => String(settings.scaling),
                "forced_extreme_periods" => forced_periods,
                "regular_periods_clustered" => full_length ÷ period_length - length(forced_periods),
                "regular_representative_periods" => settings.representative_periods - length(forced_periods),
            ),
            "clustering_features" => Dict(
                "unique_time_series" => length(clustering_sources),
                "occurrences" => sum(source.occurrences for source in clustering_sources),
                "sources" => clustering_source_data,
            ),
            "discovered_time_series" => Dict(
                "unique_time_series" => length(sources),
                "occurrences" => sum(source.occurrences for source in sources),
            ),
            "representative_periods" => tdr_representative_period_log_data(
                representative_periods,
                output_period_map,
            ),
        ),
    )
end

function tdr_write_preprocess_log!(
    case_root::String,
    sources::Vector{TimeSeriesSource},
    clustering_sources::Vector{TimeSeriesSource},
    full_length::Int,
    settings::TDRSettings,
    extreme_selections,
    representative_periods::Vector{Int},
    output_period_map::DataFrame,
    map_path::String,
    trailing_hours::Int,
)
    log_data = tdr_preprocess_log_data(
        sources,
        clustering_sources,
        full_length,
        settings,
        extreme_selections,
        representative_periods,
        output_period_map,
        map_path,
        case_root,
        trailing_hours,
    )
    write_json(joinpath(case_root, "preprocess_log.json"), log_data)
    return nothing
end
