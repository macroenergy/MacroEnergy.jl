function tdr_output_sources_from_results(results, periods::Vector{Int}, tdr_settings::TDRSettings)
    period_length = tdr_settings.timesteps_per_representative_period
    by_period = Dict(result.period => result.outputs for result in results)
    all(haskey(by_period, period) for period in periods) || throw(ArgumentError(
        "Output-based TDR did not return every candidate period.",
    ))
    output_keys = sort!(unique(reduce(vcat, [collect(keys(by_period[period])) for period in periods]; init=String[])))
    isempty(output_keys) && throw(ArgumentError("No output-based TDR features produced time-series values."))
    sources = TimeSeriesSource[]
    for key in output_keys
        matches = reduce(vcat, [get(by_period[period], key, Tuple{TDROutputFeatureSpec,Vector{Float64}}[]) for period in periods])
        provider = split(key, ":"; limit=3)[2]
        feature = tdr_selected_output_feature(unique(first.(matches)), provider)
        values = reduce(vcat, [
            begin
                period_matches = get(by_period[period], key, Tuple{TDROutputFeatureSpec,Vector{Float64}}[])
                isempty(period_matches) ? zeros(period_length) : first(period_matches)[2]
            end for period in periods
        ])
        reference = (
            json_file=nothing, input_path=Any[], feature_id=feature.id, field=feature.provider,
            asset=feature.asset, commodity=feature.commodity, user_weight=feature.user_weight,
            include_in_clustering=true,
        )
        push!(sources, TimeSeriesSource(key, nothing, nothing, nothing, Any[], values, 1,
            [reference], 1, feature.user_weight, feature.user_weight, true))
    end
    @info " -- Collected $(length(sources)) unique output time series for TDR clustering."
    return sources
end

function tdr_output_sources(
    case_root::String,
    settings_by_system::Vector{TDRSettings},
    full_lengths::Dict{Int,Int};
    run_case_kwargs::NamedTuple=NamedTuple(),
    system_scoped::Bool=true,
)
    output_data = Dict{Int,Any}()
    tasks = TDRSubperiodTask[]
    input_paths = Dict{Tuple{Int,Int},Union{Nothing,String}}()
    for (system_index, full_length) in sort!(collect(full_lengths); by=first)
        tdr_settings = settings_by_system[system_index]
        settings = tdr_settings.output_features
        isnothing(settings) && continue
        period_length = tdr_settings.timesteps_per_representative_period
        artifact_system_index = system_scoped ? system_index : nothing
        cache_path = tdr_output_features_directory(case_root; system_index=artifact_system_index)
        if settings.reuse_saved_features && tdr_saved_output_features_exist(case_root; system_index=artifact_system_index)
            @info " -- Loading saved output-based TDR features for System $system_index from `$(relpath(cache_path, case_root))`."
            sources = tdr_load_output_features(case_root, tdr_settings, full_length; system_index=artifact_system_index)
            output_data[system_index] = (sources, [Dict(
                "system_index" => system_index,
                "reused_saved_features" => true,
                "features_path" => relpath(tdr_output_features_path(case_root; system_index=artifact_system_index), case_root),
                "metadata_path" => relpath(tdr_output_metadata_path(case_root; system_index=artifact_system_index), case_root),
            )])
            continue
        elseif settings.reuse_saved_features
            @warn "Saved output-based TDR features were requested for System $system_index but do not exist under `$(relpath(cache_path, case_root))`; generating new features instead."
        end
        n_periods = full_length ÷ period_length
        for period in 1:n_periods
            input_path = nothing
            if settings.subperiod_runs.save_subperiod_inputs
                input_path = tdr_save_subperiod_inputs!(case_root, period, tdr_settings;
                    system_index=system_scoped ? system_index : nothing)
            end
            input_paths[(system_index, period)] = input_path
            push!(tasks, TDRSubperiodTask(case_root, system_index, period, tdr_settings, run_case_kwargs, input_path))
        end
    end
    isempty(tasks) && return output_data
    @info "Generating output-based TDR features."
    if any(settings -> !isnothing(settings.output_features) &&
            settings.output_features.subperiod_runs.save_subperiod_inputs, settings_by_system)
        @info " ++ Wrote $(length(tasks)) isolated TDR subperiod cases under System-specific TDR directories."
    end
    if any(settings -> !isnothing(settings.output_features) &&
            !settings.output_features.subperiod_runs.include_policy_constraints, settings_by_system)
        setup_user_additions(case_root)
        load_user_additions(case_root)
        refresh_user_type_registries!()
    end
    results, worker_ids = tdr_run_subperiod_tasks(tasks)
    @info " -- Finished $(length(tasks)) output-based TDR subperiod solves."
    for (system_index, full_length) in full_lengths
        haskey(output_data, system_index) && continue
        tdr_settings = settings_by_system[system_index]
        settings = tdr_settings.output_features
        isnothing(settings) && continue
        period_length = tdr_settings.timesteps_per_representative_period
        system_results = filter(result -> result.system_index == system_index, results)
        periods = collect(1:full_length ÷ period_length)
        sources = tdr_output_sources_from_results(system_results, periods, tdr_settings)
        @info " -- Collected $(length(sources)) unique output time series for System $system_index."
        if settings.save_features
            @info " ++ Saving output-based TDR features for System $system_index under `$(relpath(tdr_output_features_directory(case_root; system_index=system_scoped ? system_index : nothing), case_root))`."
            tdr_write_output_features!(case_root, sources, tdr_settings, full_length;
                system_index=system_scoped ? system_index : nothing)
        end
        result_paths = Dict{Int,Union{Nothing,String}}(period => nothing for period in periods)
        if settings.subperiod_runs.save_subperiod_results
            for result in system_results
                result_paths[result.period] = tdr_save_subperiod_results!(case_root, result.period, result.outputs;
                    system_index=system_scoped ? system_index : nothing)
            end
        end
        metadata = [Dict(
            "system_index" => system_index,
            "period" => result.period,
            "worker_ids" => worker_ids,
            "output_sources" => sort!(collect(keys(result.outputs))),
            "saved_input_path" => isnothing(input_paths[(system_index, result.period)]) ? nothing : relpath(input_paths[(system_index, result.period)], case_root),
            "saved_result_path" => isnothing(result_paths[result.period]) ? nothing : relpath(result_paths[result.period], case_root),
        ) for result in system_results]
        output_data[system_index] = (sources, metadata)
    end
    return output_data
end

function tdr_output_sources(
    case_root::String,
    tdr_settings::TDRSettings,
    full_length::Int;
    run_case_kwargs::NamedTuple=NamedTuple(),
)
    settings = tdr_settings.output_features
    if settings.reuse_saved_features && tdr_saved_output_features_exist(case_root)
        @info " -- Loading saved output-based TDR features from TDR/output_features."
        sources = tdr_load_output_features(case_root, tdr_settings, full_length)
        return sources, [Dict("reused_saved_features" => true,
            "features_path" => relpath(tdr_output_features_path(case_root), case_root),
            "metadata_path" => relpath(tdr_output_metadata_path(case_root), case_root))]
    end
    output_data = tdr_output_sources(case_root, [tdr_settings], Dict(1 => full_length);
        run_case_kwargs, system_scoped=false)
    return output_data[1]
end
