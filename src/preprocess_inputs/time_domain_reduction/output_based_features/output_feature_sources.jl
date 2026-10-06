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
    artifact_root::String=case_root,
    system_scoped::Bool=true,
)
    output_data = Dict{Int,Any}()
    tasks = TDRSubperiodTask[]
    input_paths = Dict{Tuple{Int,Int},Union{Nothing,String}}()
    file_hashes = Dict{String,String}()
    fingerprints = Dict{Int,Any}()
    solver_provenance = tdr_output_solver_provenance(run_case_kwargs)
    for (system_index, full_length) in sort!(collect(full_lengths); by=first)
        tdr_settings = settings_by_system[system_index]
        settings = tdr_settings.output_features
        isnothing(settings) && continue
        period_length = tdr_settings.timesteps_per_representative_period
        artifact_system_index = system_scoped ? system_index : nothing
        cache_path = tdr_output_features_directory(artifact_root; system_index=artifact_system_index)
        if settings.reuse_saved_features || settings.save_features
            fingerprints[system_index] = tdr_output_cache_fingerprint(artifact_root, tdr_settings, full_length;
                system_index=artifact_system_index, file_hashes)
        end
        if settings.reuse_saved_features && tdr_saved_output_features_exist(artifact_root; system_index=artifact_system_index)
            @info " -- Loading saved output-based TDR features for System $system_index from `$(cache_path)`."
            sources = try
                tdr_load_output_features(artifact_root, tdr_settings, full_length;
                    system_index=artifact_system_index, fingerprint=fingerprints[system_index])
            catch error
                error isa TDROutputCacheMismatch || rethrow()
                @warn "$(sprint(showerror, error)) Regenerating output features for System $system_index."
                nothing
            end
            if !isnothing(sources)
                saved_metadata = mutable_json_data(read_json(tdr_output_metadata_path(artifact_root;
                    system_index=artifact_system_index)))
                output_data[system_index] = (sources, [Dict(
                    "system_index" => system_index,
                    "reused_saved_features" => true,
                    "features_path" => tdr_output_features_path(artifact_root; system_index=artifact_system_index),
                    "metadata_path" => tdr_output_metadata_path(artifact_root; system_index=artifact_system_index),
                    "solver_provenance" => get(saved_metadata, "solver_provenance", nothing),
                )])
                continue
            end
        elseif settings.reuse_saved_features
            @warn "Saved output-based TDR features were requested for System $system_index but do not exist under `$(cache_path)`; generating new features instead."
        end
        n_periods = full_length ÷ period_length
        for period in 1:n_periods
            input_path = nothing
            if settings.subperiod_runs.save_subperiod_inputs
                input_path = tdr_save_subperiod_inputs!(case_root, period, tdr_settings;
                    system_index, artifact_root)
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
            @info " ++ Saving output-based TDR features for System $system_index under `$(tdr_output_features_directory(artifact_root; system_index=system_scoped ? system_index : nothing))`."
            tdr_write_output_features!(artifact_root, sources, tdr_settings, full_length;
                system_index=system_scoped ? system_index : nothing,
                fingerprint=fingerprints[system_index],
                solver_provenance)
        end
        result_paths = Dict{Int,Union{Nothing,String}}(period => nothing for period in periods)
        if settings.subperiod_runs.save_subperiod_results
            for result in system_results
                result_paths[result.period] = tdr_save_subperiod_results!(artifact_root, result.period, result.outputs;
                    system_index)
            end
        end
        metadata = [Dict(
            "system_index" => system_index,
            "period" => result.period,
            "worker_ids" => worker_ids,
            "output_sources" => sort!(collect(keys(result.outputs))),
            "solver_provenance" => solver_provenance,
            "saved_input_path" => input_paths[(system_index, result.period)],
            "saved_result_path" => result_paths[result.period],
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
    artifact_root::String=case_root,
)
    output_data = tdr_output_sources(case_root, [tdr_settings], Dict(1 => full_length);
        run_case_kwargs, artifact_root, system_scoped=false)
    return output_data[1]
end
