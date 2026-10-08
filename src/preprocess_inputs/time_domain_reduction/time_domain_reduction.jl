include("tdr_utilities.jl")
include("tdr_features.jl")
include("tdr_settings.jl")
include("tdr_input_formats.jl")
include("tdr_input_search.jl")
include("tdr_time_series_sources.jl")
include("tdr_candidate_periods.jl")
include("tdr_prepared_inputs.jl")
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
    case_root = abspath(case_path)
    definition = tdr_system_entries(case_root)
    number_of_systems = length(last(definition))
    parsed_settings = settings isa Vector{TDRSettings} ? settings : settings isa TDRSettings ?
        [deepcopy(settings) for _ in 1:number_of_systems] :
        load_tdr_settings_by_system(settings, number_of_systems)
    @info "*** Time-domain reduction ***"
    prepared = tdr_prepare_inputs(case_root, parsed_settings; definition)
    working_inputs = tdr_prepare_system_inputs!(case_root, prepared)
    tdr_time_domain_reduction(case_root, parsed_settings, working_inputs; output_feature_run_kwargs)
    return nothing
end

function tdr_time_domain_reduction(
    case_path::AbstractString,
    settings_by_system::Vector{TDRSettings},
    prepared;
    source_case_path::AbstractString=case_path,
    output_feature_run_kwargs::NamedTuple=NamedTuple(),
)
    case_root = abspath(case_path)
    number_of_systems = length(prepared.systems)
    @info " -- Reducing $number_of_systems Systems independently."
    output_sources = nothing
    if any(settings -> !isnothing(settings.output_features), settings_by_system)
        output_sources = tdr_output_sources(case_root, settings_by_system, prepared.systems;
            run_case_kwargs=output_feature_run_kwargs, artifact_root=abspath(source_case_path),
            system_scoped=number_of_systems > 1)
    end
    system_records = Dict{String,Any}()
    system_logs = Dict{String,Any}()
    for index in 1:number_of_systems
        @info " -- Time-clustering System $index of $number_of_systems."
        record = tdr_reduce_system!(case_root, settings_by_system[index], prepared.systems[index];
            source_case_path,
            output_data=isnothing(output_sources) ? nothing : get(output_sources, index, nothing))
        system_records["system_$index"] = record.provenance
        system_logs["system_$index"] = record.log["time_domain_reduction"]
    end
    if number_of_systems > 1
        tdr_consolidate_shared_inputs!(case_root, prepared.systems)
    end
    # Preserve the established single-System record layout; only serialization
    # and shared-file consolidation depend on the number of Systems.
    provenance = number_of_systems == 1 ? only(values(system_records)) : Dict(
        "source_case_path" => abspath(source_case_path), "systems" => system_records,
    )
    tdr_log = number_of_systems == 1 ? only(values(system_logs)) : Dict("systems" => system_logs)
    write_json(joinpath(case_root, "time_domain_reduction_provenance.json"), provenance)
    write_json(joinpath(case_root, "preprocess_log.json"), Dict("time_domain_reduction" => tdr_log))
    @info "Finished time-domain reduction for $number_of_systems Systems in `$case_root`."
    return nothing
end

"""
    tdr_reduce_system!(case_root, settings, inputs; source_case_path, output_data)

Reduce one System using its prepared inputs from [`tdr_prepare_inputs`](@ref),
translated by `tdr_prepare_system_inputs!`. Output features, when enabled, must
already be supplied in `output_data`. The caller writes root provenance/logs.
"""
function tdr_reduce_system!(
    case_root::String,
    parsed_settings::TDRSettings,
    inputs;
    source_case_path::AbstractString=case_root,
    output_data=nothing,
)
    (; system_index, sources, full_length, time_data_path, time_data, trailing_hours, candidates) = inputs
    sources = copy(sources)
    candidate_sources = tdr_candidate_sources(sources, candidates)
    clustering_sources = filter(source -> source.include_in_clustering, candidate_sources)
    candidate_length = tdr_candidate_length(candidates)
    input_periods = length(candidates.ranges)
    @info " -- Found $(length(sources)) unique input time series over $input_periods complete candidates ($candidate_length retained hours)."
    summary = tdr_candidate_summary(candidates)
    candidates.trimmed_hours_per_source_period > 0 && @info " ++ Trimming $(candidates.trimmed_hours_per_source_period) hours from each source subperiod: $(summary["trimmed_stored_hours"]) stored hours, $(summary["trimmed_represented_hours"]) represented hours. Weights retain TotalHoursModeled and redistribute omitted hours."
    trailing_hours > 0 && @info " ++ Excluding $trailing_hours trailing source hours from clustering because they do not complete a representative period."
    subperiod_results = nothing
    if !isnothing(parsed_settings.output_features)
        input_sources = copy(clustering_sources)
        output_sources, subperiod_results = output_data
        append!(sources, output_sources)
        append!(candidate_sources, output_sources)
        append!(clustering_sources, output_sources)
        tdr_set_clustering_weights!(input_sources, output_sources, parsed_settings.output_features.weight)
    end
    @info " -- Selecting representative periods using $(length(clustering_sources)) clustering time series."
    extreme_selections = tdr_extreme_period_selections(
        candidate_sources,
        parsed_settings.timesteps_per_representative_period,
        parsed_settings,
        case_root,
    )
    extreme_periods = sort!(unique(Int[selection.period for selection in extreme_selections]))
    representatives, period_map = tdr_cluster(
        clustering_sources,
        candidate_length,
        parsed_settings;
        extreme_periods,
        candidate_weights=candidates.weights,
    )
    row_indices = tdr_candidate_rows(candidates, representatives)
    @info " -- Writing $(length(representatives)) representative periods ($(length(row_indices)) hours) to the copied inputs."
    tdr_write_reduced_sources!(sources, row_indices)
    clear_csv_cache!()
    map_path, output_period_map = tdr_write_time_data!(
        time_data_path,
        case_root,
        time_data,
        representatives,
        period_map,
        candidates,
    )
    @info " ++ Reduced $input_periods input periods to $(length(representatives)) representative periods; wrote period map to `$(relpath(map_path, case_root))`."
    provenance = Dict(
        "system_index" => system_index,
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
                "subperiod_runs" => tdr_subperiod_run_settings_data(parsed_settings.output_features.subperiod_runs),
                "save_features" => parsed_settings.output_features.save_features,
                "reuse_saved_features" => parsed_settings.output_features.reuse_saved_features,
            ),
        ),
        "representative_periods" => representatives,
        "representative_period_labels" => candidates.labels[representatives],
        "forced_extreme_periods" => extreme_periods,
        "trailing_source_hours_excluded_from_tdr" => trailing_hours,
        "candidate_periods" => summary,
        "period_map_path" => relpath(map_path, case_root),
        "subperiod_solves" => isnothing(parsed_settings.output_features) ? nothing : subperiod_results,
    )
    log_data = tdr_preprocess_log_data(
        sources,
        clustering_sources,
        full_length,
        parsed_settings,
        extreme_selections,
        representatives,
        output_period_map,
        map_path,
        case_root,
        trailing_hours,
        subperiod_results;
        candidates,
    )
    @info " -- Finished time-domain reduction for System $system_index in `$case_root`."
    return (provenance=provenance, log=log_data)
end
