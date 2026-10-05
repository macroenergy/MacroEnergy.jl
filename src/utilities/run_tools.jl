"""
    run_case(case_path; kwargs...) -> (case::Case, solution::Any)

Load, solve, and write results for a Macro case. This is the main entry point for running 
a complete Macro workflow.

# Arguments
- `case_path::AbstractString`: Path to the case directory containing `system_data.json`. 
  Defaults to `@__DIR__` (the directory of the calling script).

# Keyword Arguments

## Data Loading
- `lazy_load::Bool=true`: Whether to delay loading the input data until needed.

## Logging
- `log_level::LogLevel=Logging.Info`: Logging verbosity level (e.g., `Logging.Debug`, 
  `Logging.Info`, `Logging.Warn`, `Logging.Error`). **Note**: you need to import the `Logging` 
  module to change this parameter.
- `log_to_console::Bool=true`: Whether to print log messages to the console.
- `log_to_file::Bool=true`: Whether to write log messages to a file.
- `log_file_path::AbstractString`: Path to the log file. Defaults to `<case_path>/<case_name>.log`.
- `log_file_attribution::Bool=true`: Whether to include source file attribution in log messages.

## Run status
- `write_status::Bool=true`: Whether to write a machine-readable JSON record of how the run
  ended, on both success and failure. Intended especially for external processes that need 
  to tell an infeasible model from a failed input load without parsing log output.
- `status_file_path::AbstractString`: Path to the run status file. Defaults to
  `<case_path>/run_status.json`.

## Optimizer (Monolithic/Myopic)
- `optimizer::DataType=HiGHS.Optimizer`: Optimizer constructor for Monolithic or Myopic algorithms.
- `optimizer_env::Any=nothing`: Optional optimizer environment.
- `optimizer_attributes::Tuple`: Solver-specific settings. Default: `("BarConvTol" => 1e-3, "Crossover" => 0, "Method" => 2)`.

## Optimizer (Benders)
- `planning_optimizer::DataType=HiGHS.Optimizer`: Optimizer constructor for the planning problem.
- `subproblem_optimizer::DataType=HiGHS.Optimizer`: Optimizer constructor for the subproblems.
- `planning_optimizer_attributes::Tuple`: Solver settings for the planning problem.
- `subproblem_optimizer_attributes::Tuple`: Solver settings for the subproblems.

# Returns
- `case::Case`: A case object containing a vector of solved system objects (one per period) and the case settings
- `solution`: The solution object (type depends on the solution algorithm: `Model` for 
  Monolithic, `MyopicResults` for Myopic (both Monolithic and Benders), `BendersModel`
  for Perfect Foresight + Benders). `MyopicResults.results` holds a `Vector` of per-period
  results when `ReturnModels=true`, or `nothing` when `ReturnModels=false`.

# Examples

## Basic usage with HiGHS (default)
```julia
using MacroEnergy

(case, solution) = run_case(@__DIR__);
```

## Using Gurobi optimizer
```julia
using MacroEnergy
using Gurobi

(case, solution) = run_case(
    @__DIR__;
    optimizer=Gurobi.Optimizer,
    optimizer_attributes=("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3)
);
```

## Benders decomposition with custom settings
```julia
using MacroEnergy
using Gurobi

(case, solution) = run_case(
    @__DIR__;
    planning_optimizer=Gurobi.Optimizer,
    subproblem_optimizer=Gurobi.Optimizer,
    planning_optimizer_attributes=("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3),
    subproblem_optimizer_attributes=("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3)
);
```

## Suppressing console output when running a case
```julia
using MacroEnergy
using Logging

(case, solution) = run_case(
    case_path;
    log_to_console=false,
    log_level=Logging.Warn
);
```

# Notes
- Unless `write_status=false`, a `run_status.json` file is written to the case directory
  recording the outcome of the run. `"status"` is one of:
  `"RUNNING"` (written before the work starts, so a process killed by the operating system
  does not leave the previous run's result behind), `"OK"` (solved to optimality),
  `"SUBOPTIMAL"` (a usable solution that is not provably optimal, such as a limit reached
  with a feasible incumbent), `"INFEASIBLE"`, `"INFEASIBLE_OR_UNBOUNDED"` (the solver could
  not tell the two apart), `"UNBOUNDED"`, `"SOLVE_FAILED"`, or `"ERROR"` for anything that
  is not a solve outcome, such as a failed input load. Failures also record `"exception"`
  and `"message"`, and solver failures additionally record `"termination_status"` and
  `"label"` (which identifies the period for Myopic runs). Exceptions are still thrown as
  normal.
- On success, a copy is also written into the results directory, as happens with the log
  file. The case-level file is the one to watch from outside, since it has a path known
  before the run starts and is written even when the run fails before any results directory
  exists; the copy gives each result set its own record, which the case-level file loses as
  soon as the next run overwrites it.
- The solution algorithm (Monolithic, Myopic, or Benders) is determined by the
  `SolutionAlgorithm` setting in the case's `settings/case_settings.json` file.
- For Myopic runs, results are written during iteration; no additional output writing 
  occurs after solving.
- For Benders with distributed processing enabled, worker processes are automatically 
  created and cleaned up.
"""
function run_case(
    case_path::AbstractString=@__DIR__;
    lazy_load::Bool=true,
    # Logging
    log_level::LogLevel=Logging.Info,
    log_to_console::Bool=true,
    log_to_file::Bool=true,
    log_file_path::AbstractString=joinpath(case_path, "$(basename(case_path)).log"),
    log_file_attribution::Bool=true,
    # Run status
    write_status::Bool=true,
    status_file_path::AbstractString=joinpath(case_path, "run_status.json"),
    # Monolithic or Myopic
    optimizer::DataType=HiGHS.Optimizer,
    optimizer_env::Any=nothing,
    optimizer_attributes::Tuple=("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3),
    # Benders
    planning_optimizer::DataType=HiGHS.Optimizer,
    subproblem_optimizer::DataType=HiGHS.Optimizer,
    planning_optimizer_attributes::Tuple=("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3),
    subproblem_optimizer_attributes::Tuple=("solver" => "ipm", "run_crossover" => "on", "ipm_optimality_tolerance" => 1e-3)
)
    # This will run when the Julia process closes. 
    # It may be overfill with the try-catch
    atexit(() -> try case_cleanup() catch; end)

    set_logger(log_to_console, log_to_file, log_level, log_file_path, log_file_attribution)

    start_time = time()

    # Written before the work starts, so that a run killed leaves "RUNNING" behind rather 
    # than the previous run's result
    write_status && write_run_status(status_file_path, () -> run_status_running(case_path))

    # Wrapping the work in a try-catch to all for cleanup after errors
    try
        @info("Running case at $(case_path)")

        setup_user_additions(case_path)
        load_user_additions(case_path)
        refresh_user_type_registries!()

        case, solution, output_path = Base.invokelatest(
            _run_case_impl,
            case_path,
            lazy_load,
            log_to_file,
            log_file_path,
            optimizer,
            optimizer_env,
            optimizer_attributes,
            planning_optimizer,
            subproblem_optimizer,
            planning_optimizer_attributes,
            subproblem_optimizer_attributes,
        )

        if write_status
            build_status =
                () -> run_status_success(case_path, time() - start_time, output_path, solution)
            write_run_status(status_file_path, build_status)
            # Keep a per-run copy next to the results
            write_run_status(joinpath(output_path, basename(status_file_path)), build_status)
        end

        return case, solution
    catch e
        # Payload construction is deferred into `write_run_status` so that it runs inside
        # the same guard as the write: nothing here may displace `e`
        write_status && write_run_status(
            status_file_path,
            () -> run_status_failure(case_path, time() - start_time, e),
        )
        rethrow(e)
    finally
        case_cleanup()  # Ensure all processes are removed
    end
end

function _run_case_impl(
    case_path::AbstractString,
    lazy_load::Bool,
    log_to_file::Bool,
    log_file_path::AbstractString,
    optimizer::DataType,
    optimizer_env,
    optimizer_attributes::Tuple,
    planning_optimizer::DataType,
    subproblem_optimizer::DataType,
    planning_optimizer_attributes::Tuple,
    subproblem_optimizer_attributes::Tuple,
)
    case = load_case(case_path; lazy_load=lazy_load)

    # Inputs were scaled by `parameter_scaling_factor` inside `prepare_case!`
    # (during `load_case`). Restore them after solving/writing so the returned
    # System is in original units; the `finally` guarantees this even on error.
    scaling = parameter_scaling_factor(get_settings(case))
    try
        # Create optimizer based on solution algorithm
        optimizer_instance = if isa(solution_algorithm(case), Monolithic)
            create_optimizer(optimizer, optimizer_env, optimizer_attributes)
        elseif isa(solution_algorithm(case), Benders)
            create_optimizer_benders(planning_optimizer, subproblem_optimizer,
                planning_optimizer_attributes, subproblem_optimizer_attributes)
        else
            error("Unknown solution algorithm. Please check `SolutionAlgorithm` in `settings/case_settings.json`. Valid values are \"Monolithic\" and \"Benders\".")
        end

        # If Benders, create processes for subproblems optimization
        if isa(solution_algorithm(case), Benders)
            if case.settings.BendersSettings[:Distributed]
                number_of_subproblems = sum(length(system.time_data[:Electricity].subperiods) for system in case.systems)
                start_distributed_processes!(case_path, number_of_subproblems)
            end
        end

        case, solution = solve_case(case, optimizer_instance)

        postprocess!(case, solution)

        if isa(solution, MyopicResults)
            # Outputs already written per-period during iteration; just retrieve the output path for log file copying
            output_path = solution.output_path
        else
            output_path = length(case.systems) ≥ 1 ? create_output_path(case.systems[1], case_path) : case_path
            write_outputs(output_path, case, solution)
        end

        if log_to_file && isfile(log_file_path)
            cp(log_file_path, joinpath(output_path, basename(log_file_path)); force=true)
        end

        if isa(solution_algorithm(case), Benders)
            if case.settings.BendersSettings[:Distributed] && nprocs() > 1
                rmprocs(workers())
            end
        end

        # `output_path` is returned so that `run_case` can record it in the run status file
        return case, solution, output_path
    finally
        unscale!(case, scaling)
    end
end

function case_cleanup()
    # Only remove distributed processes (workers beyond the main process)
    nprocs() > 1 && rmprocs(workers())
end

###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ######
# Run status file
#
# A machine-readable record of how a run ended, written to the case directory so that an
# external process (a sweep driver, a scheduler, a workflow tool) can tell an infeasible
# model from a failed input load without parsing log output. It is written on both success
# and failure, and survives the process exiting, unlike an exit code.
###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ######

run_status_label(e::InfeasibleModel) =
    e.status == MOI.INFEASIBLE_OR_UNBOUNDED ? "INFEASIBLE_OR_UNBOUNDED" : "INFEASIBLE"
run_status_label(::UnboundedModel) = "UNBOUNDED"
run_status_label(::SolveFailed) = "SOLVE_FAILED"
run_status_label(::Any) = "ERROR"

function run_status_base(status::AbstractString, case_path::AbstractString, elapsed::Real)
    return OrderedDict{String,Any}(
        "status" => status,
        "case_path" => abspath(case_path),
        "timestamp" => string(Dates.now()),
        "elapsed_seconds" => round(Float64(elapsed); digits = 3),
    )
end

"""
    run_status_running(case_path) -> OrderedDict{String,Any}

Build the run status payload written before the work starts.

A run killed by the operating system — a scheduler walltime, an out-of-memory kill — never
reaches either the success or the failure path, so without this marker the previous run's
file survives and a watcher reads a stale `"OK"` pointing at the previous results.
"""
run_status_running(case_path::AbstractString) = run_status_base("RUNNING", case_path, 0.0)

"""
    run_status_success(case_path, elapsed, output_path, solution) -> OrderedDict{String,Any}

Build the run status payload for a completed run. `output_path` is recorded so that a
caller which did not choose the results directory can find it.

The `status` is `"OK"` only when the solution is provably optimal, and `"SUBOPTIMAL"` when
it is merely usable — a limit reached with a feasible incumbent, or a Benders solve that
stopped short of converging. `termination_status` carries the solver's own verdict; for a
Myopic run it lists one entry per period.
"""
function run_status_success(
    case_path::AbstractString,
    elapsed::Real,
    output_path::AbstractString,
    solution,
)
    outcome = solution_outcome(solution)
    data = run_status_base(outcome.status, case_path, elapsed)
    data["output_path"] = abspath(output_path)
    isempty(outcome.termination_status) ||
        (data["termination_status"] = outcome.termination_status)
    return data
end

"""
    run_status_failure(case_path, elapsed, e) -> OrderedDict{String,Any}

Build the run status payload for a failed run. The `status` field is `"INFEASIBLE"`,
`"UNBOUNDED"`, or `"SOLVE_FAILED"` for the corresponding solver outcomes, and `"ERROR"` for
everything else (a failed input load, a bad setting, an unexpected error), so that a caller
can branch on the solve outcome without inspecting the message.
"""
function run_status_failure(case_path::AbstractString, elapsed::Real, e)
    data = run_status_base(run_status_label(e), case_path, elapsed)
    data["exception"] = string(nameof(typeof(e)))
    data["message"] = truncate_status_message(sprint(showerror, e))
    if e isa Union{InfeasibleModel,UnboundedModel,SolveFailed}
        data["termination_status"] = string(e.status)
        data["label"] = e.label
        e isa SolveFailed && (data["primal_status"] = string(e.primal))
    end
    return data
end

const MAX_STATUS_MESSAGE_CHARS = 1000

function truncate_status_message(message::AbstractString)
    length(message) <= MAX_STATUS_MESSAGE_CHARS && return String(message)
    kept = first(message, MAX_STATUS_MESSAGE_CHARS)
    return "$(kept)… (truncated; see the log file for the full message)"
end

"""
    write_run_status(file_path, build_data) -> Nothing
    write_run_status(file_path, data::AbstractDict) -> Nothing

Write a run status payload as JSON. Failures are warned about but never raised: this runs
on the error path, and must not replace the exception being reported.

Prefer the `build_data` form on the error path. It builds the payload inside the same guard
as the write, so that an exception whose `showerror` fails, or a call made from a deleted
working directory, still cannot displace the original error.

# Notes
- The directory must already exist. The status file is not a reason to create directories:
  doing so would silently produce a case directory for a mistyped path.
- Always written as plain JSON, whatever the file extension.
"""
function write_run_status(file_path::AbstractString, build_data::Function)
    try
        data = build_data()
        dir = dirname(abspath(file_path))
        isdir(dir) || error("directory $(dir) does not exist")
        # Write beside the target, on the same filesystem
        temp_path, io = mktemp(dir)
        close(io)
        try
            write_json(temp_path, data)
            mv(temp_path, file_path; force = true)
        catch
            rm(temp_path; force = true)
            rethrow()
        end
        @debug "Wrote run status to $(file_path)"
    catch err
        @warn "Could not write the run status file to $(file_path): $(err)"
    end
    return nothing
end

write_run_status(file_path::AbstractString, data::AbstractDict) =
    write_run_status(file_path, () -> data)
