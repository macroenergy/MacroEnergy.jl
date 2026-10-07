const TDR_DEFAULT_SUBPERIOD_RUN_KWARGS = (
    lazy_load=true,
    optimizer=HiGHS.Optimizer,
    optimizer_env=nothing,
    optimizer_attributes=(
        "solver" => "ipm",
        "run_crossover" => "off",
        "ipm_optimality_tolerance" => 1e-3,
    ),
)

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

"""All serializable inputs needed to run one isolated output-feature subperiod."""
struct TDRSubperiodTask
    source_case_root::String
    system_index::Int
    period::Int
    settings::TDRSettings
    run_case_kwargs::NamedTuple
    subperiod_case_root::Union{Nothing,String}
end

function tdr_subperiod_run_kwargs(run_case_kwargs::NamedTuple)
    return merge(TDR_DEFAULT_SUBPERIOD_RUN_KWARGS, run_case_kwargs)
end

function tdr_solve_subperiod_case(case_root::String, run_case_kwargs::NamedTuple)
    setup_user_additions(case_root)
    load_user_additions(case_root)
    refresh_user_type_registries!()
    return Base.invokelatest(tdr_solve_subperiod_case_impl, case_root, run_case_kwargs)
end

function tdr_solve_subperiod_case_impl(case_root::String, run_case_kwargs::NamedTuple)
    settings = tdr_subperiod_run_kwargs(run_case_kwargs)
    case = load_case(case_root; lazy_load=settings.lazy_load)
    solution_algorithm(case) isa Monolithic || throw(ArgumentError(
        "Output-based TDR currently supports the Monolithic solution algorithm.",
    ))
    scaling = parameter_scaling_factor(get_settings(case))
    try
        solution = solve_case(case, create_optimizer(
            settings.optimizer,
            settings.optimizer_env,
            settings.optimizer_attributes,
        ))
        postprocess!(case, solution)
        return only(case.systems)
    finally
        unscale!(case, scaling)
    end
end

function tdr_run_subperiod(task::TDRSubperiodTask, inputs)
    (; system_index, period, settings, run_case_kwargs, subperiod_case_root) = task
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
        tdr_materialize_subperiod_case!(inputs, temporary_case_root, period, settings)
        solve_subperiod(temporary_case_root)
    end
end

function tdr_run_subperiod_quietly(task::TDRSubperiodTask, inputs)
    return with_logger(NullLogger()) do
        tdr_run_subperiod(task, inputs)
    end
end

function tdr_run_subperiod_tasks(tasks::Vector{TDRSubperiodTask}, inputs_by_system)
    worker_ids = Int[]
    distributed = any(task -> task.settings.output_features.subperiod_runs.distributed, tasks)
    maximum_workers = maximum(task.settings.output_features.subperiod_runs.workers for task in tasks)
    results = if distributed
        @info " -- Running $(length(tasks)) output-based TDR subperiod solves on up to $maximum_workers workers."
        original_workers = Set(workers())
        new_workers = Int[]
        try
            new_workers = start_distributed_processes!(tasks[1].source_case_root, length(tasks);
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
            # Cache the captured per-System snapshots once per worker rather than
            # serializing their full profiles with every candidate task.
            pool = CachingPool(new_workers)
            try
                let prepared = inputs_by_system
                    pmap(task -> tdr_run_subperiod_quietly(task, prepared[task.system_index]), pool, tasks)
                end
            finally
                clear!(pool)
            end
        finally
            tdr_release_workers!(new_workers)
        end
    else
        results = Any[]
        for (index, task) in enumerate(tasks)
            @info " -- Running output-based TDR System $(task.system_index) subperiod $(task.period) ($(index) of $(length(tasks)))."
            push!(results, tdr_run_subperiod(task, inputs_by_system[task.system_index]))
        end
        results
    end
    return results, worker_ids
end
