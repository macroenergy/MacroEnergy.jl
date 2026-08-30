tdr_flow_provider(args...; kwargs...) = getfield(@__MODULE__, :get_optimal_flow)(args...; kwargs...)
tdr_storage_level_provider(args...; kwargs...) = getfield(@__MODULE__, :get_optimal_storage_level)(args...; kwargs...)

const TDR_WORKER_REGISTRY = Set{Int}()
const TDR_WORKER_REGISTRY_LOCK = ReentrantLock()

function tdr_cleanup_workers!()
    worker_ids = lock(TDR_WORKER_REGISTRY_LOCK) do
        ids = collect(TDR_WORKER_REGISTRY)
        empty!(TDR_WORKER_REGISTRY)
        ids
    end
    active_workers = intersect(worker_ids, workers())
    isempty(active_workers) || rmprocs(active_workers)
    return nothing
end

function tdr_register_workers!(worker_ids::AbstractVector{<:Integer})
    lock(TDR_WORKER_REGISTRY_LOCK) do
        union!(TDR_WORKER_REGISTRY, Int.(worker_ids))
    end
    return nothing
end

function tdr_release_workers!(worker_ids::AbstractVector{<:Integer})
    ids = Int.(worker_ids)
    lock(TDR_WORKER_REGISTRY_LOCK) do
        setdiff!(TDR_WORKER_REGISTRY, ids)
    end
    active_workers = intersect(ids, workers())
    isempty(active_workers) || rmprocs(active_workers)
    return nothing
end

atexit(tdr_cleanup_workers!)

const TDR_OUTPUT_PROVIDERS = Dict{String,Function}(
    "flow" => tdr_flow_provider,
    "storage_level" => tdr_storage_level_provider,
)

"""All serializable inputs needed to run one isolated output-feature subperiod."""
struct TDRSubperiodTask
    source_case_root::String
    system_index::Int
    period::Int
    settings::TDRSettings
    run_case_kwargs::NamedTuple
    subperiod_case_root::Union{Nothing,String}
end

function tdr_output_provider(name::String)::Function
    haskey(TDR_OUTPUT_PROVIDERS, name) && return TDR_OUTPUT_PROVIDERS[name]
    symbol = Symbol(name)
    isdefined(@__MODULE__, symbol) || throw(ArgumentError("Unknown output-based TDR provider `$name`."))
    provider = getfield(@__MODULE__, symbol)
    provider isa Function || throw(ArgumentError("Output-based TDR provider `$name` is not a function."))
    return provider
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

function tdr_policy_constraint_names()
    names = Set{String}()
    function collect_names(type)
        for subtype in subtypes(type)
            push!(names, String(nameof(subtype)))
            collect_names(subtype)
        end
    end
    collect_names(PolicyConstraint)
    return names
end

function tdr_remove_policy_constraints!(value, policy_names::Set{String})
    if value isa AbstractDict
        for name in policy_names
            pop!(value, name, nothing)
        end
        foreach(nested -> tdr_remove_policy_constraints!(nested, policy_names), values(value))
    elseif value isa AbstractVector
        foreach(nested -> tdr_remove_policy_constraints!(nested, policy_names), value)
    end
    return nothing
end

function tdr_write_subperiod_time_data!(time_data_path::String, source_time_data::Dict{String,Any})
    data = deepcopy(source_time_data)
    data["NumberOfSubperiods"] = 1
    pop!(data, "SubPeriodMap", nothing)
    write_json(time_data_path, data)
    return nothing
end

function tdr_copy_subperiod_case(
    source_case_root::String,
    destination_case_root::String;
    system_index::Union{Nothing,Int}=nothing,
)
    mkpath(destination_case_root)
    for name in readdir(source_case_root)
        name == "TDR" && continue
        cp(joinpath(source_case_root, name), joinpath(destination_case_root, name); force=false)
    end
    return nothing
end

function tdr_write_single_system_data!(
    source_case_root::String,
    destination_case_root::String,
    system_index::Int,
)
    _, systems = tdr_system_entries(source_case_root)
    1 <= system_index <= length(systems) || throw(ArgumentError(
        "System $system_index is outside the case's $(length(systems)) Systems.",
    ))
    write_json(joinpath(destination_case_root, "system_data.json"), deepcopy(systems[system_index]))
    return nothing
end

function tdr_write_single_system_case_settings!(
    source_case_root::String,
    destination_case_root::String,
    system_index::Int,
)
    root, systems = tdr_system_entries(source_case_root)
    length(systems) > 1 || return nothing
    haskey(root, "settings") && root["settings"] isa AbstractDict &&
        haskey(root["settings"], "path") || throw(ArgumentError(
            "Multi-System output-based TDR requires `settings.path` in system_data.json.",
        ))
    source_path = abspath(rel_or_abs_path(String(root["settings"]["path"]), source_case_root))
    isfile(source_path) || throw(ArgumentError("Case settings file does not exist: $source_path"))
    settings = mutable_json_data(read_json(source_path))
    lengths = get(settings, "PeriodLengths", nothing)
    lengths isa AbstractVector && length(lengths) >= system_index || throw(ArgumentError(
        "Case settings `PeriodLengths` must contain a period length for System $system_index.",
    ))
    settings["PeriodLengths"] = Any[lengths[system_index]]
    # Each output-feature subproblem represents one independent operational
    # System. A source Case may be Myopic, but retaining that horizon causes
    # the one-period solve to release its JuMP model before providers can read
    # flows or storage levels. There is no inter-System carry-over here, so a
    # one-period PerfectForesight solve is the appropriate isolated model.
    settings["ExpansionHorizon"] = "PerfectForesight"
    destination_path = joinpath(destination_case_root, "settings", "case_settings.json")
    mkpath(dirname(destination_path))
    write_json(destination_path, settings)
    return nothing
end

function tdr_materialize_subperiod_case!(
    source_case_root::String,
    destination_case_root::String,
    period::Int,
    settings::TDRSettings,
    ; system_index::Union{Nothing,Int}=nothing,
)
    tdr_copy_subperiod_case(source_case_root, destination_case_root; system_index)
    if !isnothing(system_index) && length(last(tdr_system_entries(source_case_root))) > 1
        tdr_write_single_system_data!(source_case_root, destination_case_root, system_index)
        tdr_write_single_system_case_settings!(source_case_root, destination_case_root, system_index)
    end
    sources, _, full_length, time_data_path, time_data, _ = tdr_sources(destination_case_root, settings)
    period_length = settings.timesteps_per_representative_period
    n_periods = full_length ÷ period_length
    1 <= period <= n_periods || throw(ArgumentError("Subperiod $period is outside the $n_periods-period input horizon."))
    indices = collect((period - 1) * period_length + 1:period * period_length)
    tdr_write_reduced_sources!(sources, indices)
    tdr_write_subperiod_time_data!(time_data_path, time_data)
    if !settings.output_features.subperiod_runs.include_policy_constraints
        policy_names = tdr_policy_constraint_names()
        for path in tdr_input_json_files(destination_case_root)
            data = mutable_json_data(read_json(path))
            tdr_remove_policy_constraints!(data, policy_names)
            write_json(path, data)
        end
    end
    clear_csv_cache!()
    return nothing
end

function tdr_solve_subperiod_case(case_root::String, run_case_kwargs::NamedTuple)
    setup_user_additions(case_root)
    load_user_additions(case_root)
    refresh_user_type_registries!()
    return Base.invokelatest(tdr_solve_subperiod_case_impl, case_root, run_case_kwargs)
end

function tdr_solve_subperiod_case_impl(case_root::String, run_case_kwargs::NamedTuple)
    case = load_case(case_root; lazy_load=get(run_case_kwargs, :lazy_load, true))
    solution_algorithm(case) isa Monolithic || throw(ArgumentError(
        "Output-based TDR currently supports the Monolithic solution algorithm.",
    ))
    optimizer = get(run_case_kwargs, :optimizer, HiGHS.Optimizer)
    optimizer_env = get(run_case_kwargs, :optimizer_env, nothing)
    optimizer_attributes = get(run_case_kwargs, :optimizer_attributes, (
        "solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3,
    ))
    scaling = parameter_scaling_factor(get_settings(case))
    try
        solution = solve_case(case, create_optimizer(optimizer, optimizer_env, optimizer_attributes))
        postprocess!(case, solution)
        return only(case.systems)
    finally
        unscale!(case, scaling)
    end
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

function tdr_run_subperiod(
    source_case_root::String,
    system_index::Int,
    period::Int,
    settings::TDRSettings,
    run_case_kwargs::NamedTuple,
    subperiod_case_root::Union{Nothing,String}=nothing,
)
    function solve_subperiod(case_root::String)
        try
            system = tdr_solve_subperiod_case(case_root, run_case_kwargs)
            outputs = tdr_subperiod_output_data(
                system,
                settings.output_features,
                settings.timesteps_per_representative_period,
            )
            return (system_index=system_index, period=period, outputs=outputs)
        catch error
            throw(ErrorException(
                "Output-based TDR System $system_index subperiod $period failed: $(sprint(showerror, error))",
            ))
        end
    end
    if !isnothing(subperiod_case_root)
        return solve_subperiod(subperiod_case_root)
    end
    return mktempdir() do temporary_root
        temporary_case_root = joinpath(temporary_root, "case")
        tdr_materialize_subperiod_case!(source_case_root, temporary_case_root, period, settings; system_index)
        solve_subperiod(temporary_case_root)
    end
end

function tdr_run_subperiod_quietly(args...)
    return with_logger(NullLogger()) do
        tdr_run_subperiod(args...)
    end
end

function tdr_run_subperiod_quietly(task::TDRSubperiodTask)
    return with_logger(NullLogger()) do
        tdr_run_subperiod(
            task.source_case_root,
            task.system_index,
            task.period,
            task.settings,
            task.run_case_kwargs,
            task.subperiod_case_root,
        )
    end
end

function tdr_saved_subperiod_directory(
    case_root::String,
    period::Int;
    system_index::Union{Nothing,Int}=nothing,
)
    directory = isnothing(system_index) ?
        joinpath(case_root, "TDR", "subperiod_solves") :
        joinpath(case_root, "TDR", "systems", "system_$system_index", "subperiod_solves")
    return joinpath(directory, "period_$(lpad(period, 4, '0'))")
end

function tdr_subperiod_run_settings_data(settings::TDRSubperiodRunSettings)
    return Dict(
        "distributed" => settings.distributed,
        "workers" => settings.workers,
        "include_policy_constraints" => settings.include_policy_constraints,
        "save_subperiod_inputs" => settings.save_subperiod_inputs,
        "save_subperiod_results" => settings.save_subperiod_results,
    )
end

function tdr_save_subperiod_inputs!(
    case_root::String,
    period::Int,
    settings::TDRSettings;
    system_index::Union{Nothing,Int}=nothing,
)
    destination = tdr_saved_subperiod_directory(case_root, period; system_index)
    ispath(destination) && rm(destination; recursive=true, force=true)
    mktempdir() do temporary_root
        temporary_case = joinpath(temporary_root, "case")
        tdr_materialize_subperiod_case!(case_root, temporary_case, period, settings; system_index)
        mkpath(dirname(destination))
        mv(temporary_case, destination)
    end
    return destination
end

function tdr_save_subperiod_results!(
    case_root::String,
    period::Int,
    outputs;
    system_index::Union{Nothing,Int}=nothing,
)
    destination = tdr_saved_subperiod_directory(case_root, period; system_index)
    mkpath(destination)
    data = Dict(
        "system_index" => system_index,
        "period" => period,
        "outputs" => Dict(
            key => [Dict(
                "feature" => Dict(
                    "provider" => feature.provider,
                    "id" => feature.id,
                    "asset" => feature.asset,
                    "commodity" => feature.commodity,
                    "weight" => feature.user_weight,
                ),
                "values" => values,
            ) for (feature, values) in matches]
            for (key, matches) in outputs
        ),
    )
    path = joinpath(destination, "results.json.gz")
    write_json(path, data, true)
    return path
end

function tdr_output_sources_from_results(
    results,
    periods::Vector{Int},
    tdr_settings::TDRSettings,
)
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
    worker_ids = Int[]
    distributed = any(task -> task.settings.output_features.subperiod_runs.distributed, tasks)
    maximum_workers = maximum(task.settings.output_features.subperiod_runs.workers for task in tasks)
    results = if distributed
        @info " -- Running $(length(tasks)) output-based TDR subperiod solves on up to $maximum_workers workers."
        original_workers = Set(workers())
        new_workers = Int[]
        try
            new_workers = start_distributed_processes!(case_root, length(tasks);
                max_workers=maximum_workers, quiet=true)
        catch
            new_workers = setdiff(workers(), collect(original_workers))
            tdr_register_workers!(new_workers)
            tdr_release_workers!(new_workers)
            rethrow()
        end
        tdr_register_workers!(new_workers)
        worker_ids = copy(new_workers)
        try
            pmap(tdr_run_subperiod_quietly, WorkerPool(new_workers), tasks)
        finally
            tdr_release_workers!(new_workers)
        end
    else
        results = Any[]
        for (index, task) in enumerate(tasks)
            @info " -- Running output-based TDR System $(task.system_index) subperiod $(task.period) ($(index) of $(length(tasks)))."
            push!(results, tdr_run_subperiod(task.source_case_root, task.system_index, task.period,
                task.settings, task.run_case_kwargs, task.subperiod_case_root))
        end
        results
    end
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
    # Keep single-System artifact locations stable while sharing the multi-System runner.
    settings = tdr_settings.output_features
    if settings.reuse_saved_features && tdr_saved_output_features_exist(case_root)
        @info " -- Loading saved output-based TDR features from TDR/output_features."
        sources = tdr_load_output_features(case_root, tdr_settings, full_length)
        return sources, [Dict("reused_saved_features" => true,
            "features_path" => relpath(tdr_output_features_path(case_root), case_root),
            "metadata_path" => relpath(tdr_output_metadata_path(case_root), case_root))]
    end
    # A synthetic one-System case is intentionally used here to retain the existing paths.
    output_data = tdr_output_sources(case_root, [tdr_settings], Dict(1 => full_length);
        run_case_kwargs, system_scoped=false)
    return output_data[1]
end
