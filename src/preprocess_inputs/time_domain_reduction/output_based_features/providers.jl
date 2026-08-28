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

function tdr_copy_subperiod_case(source_case_root::String, destination_case_root::String)
    mkpath(destination_case_root)
    for name in readdir(source_case_root)
        name == "TDR" && continue
        cp(joinpath(source_case_root, name), joinpath(destination_case_root, name); force=false)
    end
    return nothing
end

function tdr_materialize_subperiod_case!(
    source_case_root::String,
    destination_case_root::String,
    period::Int,
    settings::TDRSettings,
)
    tdr_copy_subperiod_case(source_case_root, destination_case_root)
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
            return (period=period, outputs=outputs)
        catch error
            throw(ErrorException("Output-based TDR subperiod $period failed: $(sprint(showerror, error))"))
        end
    end
    if !isnothing(subperiod_case_root)
        return solve_subperiod(subperiod_case_root)
    end
    return mktempdir() do temporary_root
        temporary_case_root = joinpath(temporary_root, "case")
        tdr_materialize_subperiod_case!(source_case_root, temporary_case_root, period, settings)
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
            task.period,
            task.settings,
            task.run_case_kwargs,
            task.subperiod_case_root,
        )
    end
end

tdr_saved_subperiod_directory(case_root::String, period::Int) =
    joinpath(case_root, "TDR", "subperiod_solves", "period_$(lpad(period, 4, '0'))")

function tdr_subperiod_run_settings_data(settings::TDRSubperiodRunSettings)
    return Dict(
        "distributed" => settings.distributed,
        "workers" => settings.workers,
        "include_policy_constraints" => settings.include_policy_constraints,
        "save_subperiod_inputs" => settings.save_subperiod_inputs,
        "save_subperiod_results" => settings.save_subperiod_results,
    )
end

function tdr_save_subperiod_inputs!(case_root::String, period::Int, settings::TDRSettings)
    destination = tdr_saved_subperiod_directory(case_root, period)
    ispath(destination) && rm(destination; recursive=true, force=true)
    mktempdir() do temporary_root
        temporary_case = joinpath(temporary_root, "case")
        tdr_materialize_subperiod_case!(case_root, temporary_case, period, settings)
        mkpath(dirname(destination))
        mv(temporary_case, destination)
    end
    return destination
end

function tdr_save_subperiod_results!(case_root::String, period::Int, outputs)
    destination = tdr_saved_subperiod_directory(case_root, period)
    mkpath(destination)
    data = Dict(
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
        @info " ++ Loaded $(length(sources)) saved output time series for TDR clustering."
        return sources, [Dict(
            "reused_saved_features" => true,
            "features_path" => relpath(tdr_output_features_path(case_root), case_root),
            "metadata_path" => relpath(tdr_output_metadata_path(case_root), case_root),
        )]
    elseif settings.reuse_saved_features
        @warn "Saved output-based TDR features were requested but do not exist under TDR/output_features; generating new features instead."
    end
    @info "Generating output-based TDR features."
    if !settings.subperiod_runs.include_policy_constraints
        setup_user_additions(case_root)
        load_user_additions(case_root)
        refresh_user_type_registries!()
    end
    period_length = tdr_settings.timesteps_per_representative_period
    n_periods = full_length ÷ period_length
    periods = collect(1:n_periods)
    @info " -- Preparing $n_periods isolated subperiod cases for output-based TDR."
    input_paths = Dict{Int,Union{Nothing,String}}(period => nothing for period in periods)
    if settings.subperiod_runs.save_subperiod_inputs
        @info " ++ Writing isolated TDR subperiod inputs under TDR/subperiod_solves."
        for period in periods
            input_paths[period] = tdr_save_subperiod_inputs!(case_root, period, tdr_settings)
        end
        @info " ++ Finished writing $n_periods isolated TDR subperiod cases."
    end
    results = if settings.subperiod_runs.distributed
        @info " -- Running output-based TDR subperiod solves on up to $(settings.subperiod_runs.workers) workers."
        original_workers = Set(workers())
        new_workers = Int[]
        try
            new_workers = start_distributed_processes!(
                case_root,
                Int(n_periods);
                max_workers=settings.subperiod_runs.workers,
                quiet=true,
            )
        catch
            new_workers = setdiff(workers(), collect(original_workers))
            tdr_register_workers!(new_workers)
            tdr_release_workers!(new_workers)
            rethrow()
        end
        tdr_register_workers!(new_workers)
        try
            tasks = [TDRSubperiodTask(
                    case_root,
                    period,
                    tdr_settings,
                    run_case_kwargs,
                    input_paths[period],
                ) for period in periods]
            results = pmap(
                tdr_run_subperiod_quietly,
                WorkerPool(new_workers),
                tasks,
            )
            @info " -- Finished $n_periods output-based TDR subperiod solves."
            results
        finally
            tdr_release_workers!(new_workers)
        end
    else
        results = Any[]
        for period in periods
            @info " -- Running output-based TDR subperiod $period of $n_periods."
            push!(results, tdr_run_subperiod(
                case_root,
                period,
                tdr_settings,
                run_case_kwargs,
                input_paths[period],
            ))
        end
        @info " -- Finished $n_periods output-based TDR subperiod solves."
        results
    end

    by_period = Dict(result.period => result.outputs for result in results)
    all(haskey(by_period, period) for period in periods) || throw(ArgumentError("Output-based TDR did not return every candidate period."))
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
    if settings.save_features
        @info " ++ Saving output-based TDR features under TDR/output_features."
        tdr_write_output_features!(case_root, sources, tdr_settings, full_length)
    end
    result_paths = Dict{Int,Union{Nothing,String}}(period => nothing for period in periods)
    if settings.subperiod_runs.save_subperiod_results
        @info " ++ Saving output-based TDR subperiod results under TDR/subperiod_solves."
        for result in results
            result_paths[result.period] = tdr_save_subperiod_results!(case_root, result.period, result.outputs)
        end
    end
    metadata = [Dict(
        "period" => result.period,
        "output_sources" => sort!(collect(keys(result.outputs))),
        "saved_input_path" => isnothing(input_paths[result.period]) ? nothing : relpath(input_paths[result.period], case_root),
        "saved_result_path" => isnothing(result_paths[result.period]) ? nothing : relpath(result_paths[result.period], case_root),
    ) for result in results]
    return sources, metadata
end
