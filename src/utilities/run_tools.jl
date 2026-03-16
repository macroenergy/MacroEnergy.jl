"""
    run_case(case_path; kwargs...) -> (systems::Vector{System}, solution::Any)

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
- `systems::Vector{System}`: Vector of solved system objects (one per period).
- `solution`: The solution object (type depends on the solution algorithm: `Model` for 
  Monolithic, `MyopicResults` for Myopic, `BendersResults` for Benders).

# Examples

## Basic usage with HiGHS (default)
```julia
using MacroEnergy

(systems, solution) = run_case(@__DIR__);
```

## Using Gurobi optimizer
```julia
using MacroEnergy
using Gurobi

(systems, solution) = run_case(
    @__DIR__;
    optimizer=Gurobi.Optimizer,
    optimizer_attributes=("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3)
);
```

## Benders decomposition with custom settings
```julia
using MacroEnergy
using Gurobi

(systems, solution) = run_case(
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

(systems, solution) = run_case(
    case_path;
    log_to_console=false,
    log_level=Logging.Warn
);
```

# Notes
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

    # Wrapping the work in a try-catch to all for cleanup after errors
    try 
        @info("Running case at $(case_path)")

        create_user_additions_module(case_path)
        load_user_additions(case_path)

        case = load_case(case_path; lazy_load=lazy_load)

        # Create optimizer based on solution algorithm
        optimizer = if isa(solution_algorithm(case), Monolithic) || isa(solution_algorithm(case), Myopic)
            create_optimizer(optimizer, optimizer_env, optimizer_attributes)
        elseif isa(solution_algorithm(case), Benders)
            create_optimizer_benders(planning_optimizer, subproblem_optimizer,
                planning_optimizer_attributes, subproblem_optimizer_attributes)
        else
            error("The solution algorithm is not Monolithic, Myopic, or Benders. Please double check the `SolutionAlgorithm` in the `settings/case_settings.json` file.")
        end

        # If Benders, create processes for subproblems optimization
        if isa(solution_algorithm(case), Benders)
            if case.settings.BendersSettings[:Distributed]
                number_of_subproblems = sum(length(system.time_data[:Electricity].subperiods) for system in case.systems)
                start_distributed_processes!(number_of_subproblems, case_path)
            end
        end

        (case, solution) = solve_case(case, optimizer)

        # Myopic outputs are written during iteration, so we don't need to write them here
        if !isa(solution_algorithm(case), Myopic)
            if length(case.systems) ≥ 1
                case_path = create_output_path(case.systems[1], case_path)
            end
            write_outputs(case_path, case, solution)
        end

        # If Benders, delete processes
        if isa(solution_algorithm(case), Benders)
            if case.settings.BendersSettings[:Distributed] && nprocs() > 1
                rmprocs(workers())
            end
        end

        return case.systems, solution
    catch e
        rethrow(e)
    finally
        case_cleanup()  # Ensure all processes are removed
    end
end

function case_cleanup()
    # Only remove distributed processes (workers beyond the main process)
    nprocs() > 1 && rmprocs(workers())
end