include("tdr_utilities.jl")
include("tdr_features.jl")
include("tdr_settings.jl")
include("tdr_input_search.jl")
include("tdr_time_series_sources.jl")
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
    number_of_systems = length(last(tdr_system_entries(abspath(case_path))))
    parsed_settings = settings isa Vector{TDRSettings} ? settings : settings isa TDRSettings ?
        [deepcopy(settings) for _ in 1:number_of_systems] :
        load_tdr_settings_by_system(settings, number_of_systems)
    @info "*** Time-domain reduction ***"
    tdr_time_domain_reduction(abspath(case_path), parsed_settings; output_feature_run_kwargs)
    return nothing
end

function tdr_time_domain_reduction(
    case_path::AbstractString,
    settings_by_system::Vector{TDRSettings};
    source_case_path::AbstractString=case_path,
    output_feature_run_kwargs::NamedTuple=NamedTuple(),
    inputs_prepared::Bool=false,
)
    case_root = abspath(case_path)
    number_of_systems = inputs_prepared ? length(last(tdr_system_entries(case_root))) :
        tdr_prepare_system_inputs!(case_root; source_case_root=source_case_path)
    length(settings_by_system) == number_of_systems || throw(ArgumentError(
        "TDR received $(length(settings_by_system)) settings objects for a Case with $number_of_systems Systems.",
    ))
    number_of_systems == 1 && return tdr_time_domain_reduction(case_root, only(settings_by_system);
        source_case_path, output_feature_run_kwargs, inputs_prepared=true)
    @info " -- Reducing $number_of_systems Systems independently."
    output_sources = nothing
    if any(settings -> !isnothing(settings.output_features), settings_by_system)
        full_lengths = Dict(index => first(tdr_full_length(tdr_system_time_data_path(case_root, index)))
            for index in 1:number_of_systems)
        output_sources = tdr_output_sources(case_root, settings_by_system, full_lengths;
            run_case_kwargs=output_feature_run_kwargs)
    end
    system_records = Dict{String,Any}()
    system_logs = Dict{String,Any}()
    for index in 1:number_of_systems
        @info " -- Time-clustering System $index of $number_of_systems."
        record = tdr_time_domain_reduction(case_root, settings_by_system[index];
            source_case_path, output_feature_run_kwargs, system_index=index,
            precomputed_output=isnothing(output_sources) || !haskey(output_sources, index) ? nothing : output_sources[index],
            write_root_records=false)
        system_records["system_$index"] = record.provenance
        system_logs["system_$index"] = record.log["time_domain_reduction"]
    end
    tdr_consolidate_shared_time_series!(case_root, settings_by_system, number_of_systems)
    write_json(joinpath(case_root, "time_domain_reduction_provenance.json"), Dict(
        "source_case_path" => abspath(source_case_path), "systems" => system_records,
    ))
    write_json(joinpath(case_root, "preprocess_log.json"), Dict(
        "time_domain_reduction" => Dict("systems" => system_logs),
    ))
    @info "Finished time-domain reduction for $number_of_systems Systems in `$case_root`."
    return nothing
end

function tdr_time_domain_reduction(
    case_path::AbstractString,
    parsed_settings::TDRSettings;
    source_case_path::AbstractString=case_path,
    output_feature_run_kwargs::NamedTuple=NamedTuple(),
    system_index::Union{Nothing,Int}=nothing,
    precomputed_output=nothing,
    write_root_records::Bool=true,
    inputs_prepared::Bool=false,
)
    case_root = abspath(case_path)
    isdir(case_root) || throw(ArgumentError("Case directory does not exist: $case_root"))
    if isnothing(system_index)
        number_of_systems = inputs_prepared ? length(last(tdr_system_entries(case_root))) :
            tdr_prepare_system_inputs!(case_root; source_case_root=source_case_path)
        if number_of_systems > 1
            @info " -- Reducing $number_of_systems Systems independently."
            output_sources = nothing
            if !isnothing(parsed_settings.output_features)
                full_lengths = Dict(
                    index => first(tdr_full_length(tdr_system_time_data_path(case_root, index)))
                    for index in 1:number_of_systems
                )
                output_sources = tdr_output_sources(
                    case_root,
                    parsed_settings,
                    full_lengths;
                    run_case_kwargs=output_feature_run_kwargs,
                )
            end
            system_records = Dict{String,Any}()
            system_logs = Dict{String,Any}()
            for index in 1:number_of_systems
                @info " -- Time-clustering System $index of $number_of_systems."
                record = tdr_time_domain_reduction(
                    case_root,
                    parsed_settings;
                    source_case_path,
                    output_feature_run_kwargs,
                    system_index=index,
                    precomputed_output=isnothing(output_sources) ? nothing : output_sources[index],
                    write_root_records=false,
                )
                system_records["system_$index"] = record.provenance
                system_logs["system_$index"] = record.log["time_domain_reduction"]
            end
            tdr_consolidate_shared_time_series!(case_root,
                [deepcopy(parsed_settings) for _ in 1:number_of_systems], number_of_systems)
            write_json(joinpath(case_root, "time_domain_reduction_provenance.json"), Dict(
                "source_case_path" => abspath(source_case_path),
                "systems" => system_records,
            ))
            write_json(joinpath(case_root, "preprocess_log.json"), Dict(
                "time_domain_reduction" => Dict("systems" => system_logs),
            ))
            @info "Finished time-domain reduction for $number_of_systems Systems in `$case_root`."
            return nothing
        end
        system_index = 1
    end

    sources, clustering_sources, full_length, time_data_path, time_data, trailing_hours =
        tdr_sources(case_root, parsed_settings; system_index)
    input_periods = full_length ÷ parsed_settings.timesteps_per_representative_period
    @info " -- Found $(length(sources)) unique input time series over $input_periods complete periods ($(full_length) hours)."
    trailing_hours > 0 && @info " ++ Excluding $trailing_hours trailing source hours from clustering because they do not complete a representative period."
    subperiod_results = nothing
    if !isnothing(parsed_settings.output_features)
        input_sources = copy(clustering_sources)
        output_sources, subperiod_results = isnothing(precomputed_output) ?
            tdr_output_sources(case_root, parsed_settings, full_length;
                run_case_kwargs=output_feature_run_kwargs) : precomputed_output
        append!(sources, output_sources)
        append!(clustering_sources, output_sources)
        tdr_set_clustering_weights!(input_sources, output_sources, parsed_settings.output_features.weight)
    end
    @info " -- Selecting representative periods using $(length(clustering_sources)) clustering time series."
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
    @info " -- Writing $(length(representatives)) representative periods ($(length(row_indices)) hours) to the copied inputs."
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
        "forced_extreme_periods" => extreme_periods,
        "trailing_source_hours_excluded_from_tdr" => trailing_hours,
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
        subperiod_results,
    )
    if write_root_records
        write_json(joinpath(case_root, "time_domain_reduction_provenance.json"), provenance)
        write_json(joinpath(case_root, "preprocess_log.json"), log_data)
    end
    @info " -- Finished time-domain reduction for System $system_index in `$case_root`."
    return (provenance=provenance, log=log_data)
end
