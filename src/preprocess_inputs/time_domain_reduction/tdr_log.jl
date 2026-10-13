"""Physical location of a logged input series or generated output feature.

`type` is `"csv"`, `"inline_json"` or `"output_feature"`. Optional location fields
are omitted from JSON when they do not apply to that source type.
"""
Base.@kwdef struct TDRLogLocation
    type::String
    path::Union{Nothing,String} = nothing
    header::Union{Nothing,String} = nothing
    input_path::Vector{String} = String[]
end

"""One logical reference to a logged series, including its clustering decision.

An output feature has no input-file `path`. `clustering_exclusion_reason` is
`nothing` for a clustered reference; otherwise it records `"no_matching_feature"`,
`"explicitly_excluded"` or `"zero_clustering_weight"`.
"""
Base.@kwdef struct TDRLogReference
    path::Union{Nothing,String} = nothing
    input_path::Vector{String} = String[]
    field::String = ""
    feature_id::Union{Nothing,String} = nothing
    include_in_clustering::Bool = false
    clustering_exclusion_reason::Union{Nothing,String} = nothing
end

"""One physical series in the discovered-input or clustering-source log.

`source` identifies its location; the selector lists summarize `references`.
`occurrences` counts logical uses, `user_weight` is the configured feature weight
and `weight` records the series weight. `include_in_clustering` reports actual
clustering membership. `reduced` indicates whether the series is written back
into model inputs; generated output features are not reduced.
"""
Base.@kwdef struct TDRLogEntry
    source::TDRLogLocation
    feature_ids::Vector{String} = String[]
    fields::Vector{String} = String[]
    assets::Vector{String} = String[]
    commodities::Vector{String} = String[]
    occurrences::Int = 0
    user_weight::Float64 = 1.0
    weight::Float64 = 0.0
    include_in_clustering::Bool = false
    reduced::Bool = false
    references::Vector{TDRLogReference} = TDRLogReference[]
end

# Keep the existing JSON layout explicit at the serialization boundary.
function tdr_log_data(location::TDRLogLocation)
    data = Dict{String,Any}("type" => location.type)
    if location.type == "csv"
        data["path"] = location.path
        data["header"] = location.header
    elseif location.type == "inline_json"
        data["path"] = location.path
        data["input_path"] = location.input_path
    end
    return data
end

tdr_log_data(reference::TDRLogReference) = Dict(
    "path" => reference.path, "input_path" => reference.input_path,
    "field" => reference.field, "feature_id" => reference.feature_id,
    "include_in_clustering" => reference.include_in_clustering,
    "clustering_exclusion_reason" => reference.clustering_exclusion_reason,
)

tdr_log_data(entry::TDRLogEntry) = Dict(
    "source" => tdr_log_data(entry.source), "feature_ids" => entry.feature_ids,
    "fields" => entry.fields, "assets" => entry.assets, "commodities" => entry.commodities,
    "occurrences" => entry.occurrences, "user_weight" => entry.user_weight,
    "weight" => entry.weight, "include_in_clustering" => entry.include_in_clustering,
    "reduced" => entry.reduced, "references" => tdr_log_data.(entry.references),
)

function TDRLogEntry(source::TimeSeriesSource, case_root::String;
    include_in_clustering::Bool=source.include_in_clustering)
    references = source.references
    location = if !isnothing(source.csv_path)
        TDRLogLocation(type="csv", path=tdr_relative_path(case_root, source.csv_path),
            header=String(source.header))
    elseif !isnothing(source.inline_file)
        TDRLogLocation(type="inline_json", path=tdr_relative_path(case_root, source.inline_file),
            input_path=string.(source.inline_path))
    else
        TDRLogLocation(type="output_feature")
    end
    return TDRLogEntry(
        source=location,
        feature_ids=sort!(unique(String[
            reference.feature_id for reference in references if !isnothing(reference.feature_id)
        ])),
        fields=sort!(unique(String[reference.field for reference in references])),
        assets=sort!(unique(String[
            reference.asset for reference in references if !isnothing(reference.asset)
        ])),
        commodities=sort!(unique(String[
            reference.commodity for reference in references if !isnothing(reference.commodity)
        ])),
        occurrences=source.occurrences,
        user_weight=source.user_weight,
        weight=source.weight,
        include_in_clustering=include_in_clustering,
        reduced=!isnothing(source.csv_path) || !isnothing(source.inline_file),
        references=[TDRLogReference(
            path=isnothing(reference.json_file) ? nothing : tdr_relative_path(case_root, reference.json_file),
            input_path=string.(reference.input_path), field=reference.field,
            feature_id=reference.feature_id,
            include_in_clustering=reference.include_in_clustering && include_in_clustering,
            clustering_exclusion_reason=reference.include_in_clustering ?
                (include_in_clustering ? nothing : "zero_clustering_weight") :
                get(reference, :clustering_exclusion_reason,
                    isnothing(reference.feature_id) ? "no_matching_feature" : "explicitly_excluded"),
        ) for reference in references],
    )
end

function tdr_source_log_data(source::TimeSeriesSource, case_root::String;
    include_in_clustering::Bool=source.include_in_clustering)
    return tdr_log_data(TDRLogEntry(source, case_root; include_in_clustering))
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
    subperiod_solves;
    candidates::Union{Nothing,TDRCandidatePeriods}=nothing,
)
    forced_periods = sort!(unique(Int[selection.period for selection in extreme_selections]))
    period_length = settings.timesteps_per_representative_period
    input_periods = isnothing(candidates) ? full_length ÷ period_length : length(candidates.ranges)
    temporal_summary = Dict{String,Any}(
        "original_hours" => full_length,
        "trailing_source_hours_excluded_from_tdr" => trailing_hours,
        "original_periods" => input_periods,
        "period_map_rows" => nrow(output_period_map),
        "timesteps_per_representative_period" => period_length,
        "representative_periods" => length(representative_periods),
        "reduced_hours" => length(representative_periods) * period_length,
        "period_map_path" => tdr_relative_path(case_root, map_path),
    )
    !isnothing(candidates) && merge!(temporal_summary, tdr_candidate_summary(candidates))
    clustering_source_data = [
        tdr_source_log_data(source, case_root)
        for source in sort(clustering_sources; by=source -> source.key)
    ]
    clustering_keys = Set(source.key for source in clustering_sources)
    return Dict(
        "time_domain_reduction" => Dict(
            "temporal_summary" => temporal_summary,
            "extreme_periods" => tdr_extreme_period_selection_data.(extreme_selections),
            "clustering" => Dict(
                "method" => String(tdr_method_name(settings.method_settings)),
                "method_settings" => tdr_method_settings_data(settings.method_settings),
                "scaling" => String(settings.scaling),
                "forced_extreme_periods" => forced_periods,
                "regular_periods_clustered" => input_periods - length(forced_periods),
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
                "sources" => [tdr_source_log_data(source, case_root;
                    include_in_clustering=source.key in clustering_keys)
                    for source in sort(sources; by=source -> source.key)],
            ),
            "subperiod_solves" => subperiod_solves,
            "representative_periods" => tdr_representative_period_log_data(
                representative_periods,
                output_period_map,
            ),
        ),
    )
end

"""Write assembled Case-level provenance and preprocessing logs in `preprocessing_logs/`.

The caller supplies the complete records, including any per-System grouping.
This writer owns directory creation and filenames; it does not rebuild log data.
"""
function tdr_write_preprocessing_logs!(case_root::String, provenance::AbstractDict, log_data::AbstractDict)
    log_root = mkpath(joinpath(case_root, "preprocessing_logs"))
    write_json(joinpath(log_root, "time_domain_reduction_provenance.json"), provenance)
    write_json(joinpath(log_root, "preprocess_log.json"), log_data)
    return nothing
end
