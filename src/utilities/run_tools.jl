function run_case(
    case_path::AbstractString=@__DIR__;
    lazy_load::Bool=true,
    # Logging
    log_level::LogLevel=Logging.Info,
    log_to_console::Bool=true,
    log_to_file::Bool=true,
    log_file_path::AbstractString=joinpath(case_path, "$(basename(case_path)).log"),
    log_file_attribution::Bool=true,
    use_preallocation::Bool=false,  # New preallocation flag
    # Preallocation option
    use_preallocation::Bool=false,
    # Monolithic or Myopic
    optimizer::DataType=HiGHS.Optimizer,
    optimizer_env::Any=nothing,
    optimizer_attributes::Tuple=("BarConvTol" => 1e-3, "Crossover" => 0, "Method" => 2),
    # Benders
    planning_optimizer::DataType=HiGHS.Optimizer,
    subproblem_optimizer::DataType=HiGHS.Optimizer,
    planning_optimizer_attributes::Tuple=("BarConvTol" => 1e-3, "Crossover" => 0, "Method" => 2),
    subproblem_optimizer_attributes::Tuple=("BarConvTol" => 1e-3, "Crossover" => 0, "Method" => 2)
)
    # This will run when the Julia process closes. 
    # It may be overfill with the try-catch
    atexit(() -> try case_cleanup() catch; end)

    set_logger(log_to_console, log_to_file, log_level, log_file_path, log_file_attribution)

    # Wrapping the work in a try-catch to all for cleanup after errors
    try 
        @info("Running case at $(case_path)")

        create_user_additions_module(case_path)
        additions_path = user_additions_module_path(case_path)
        load_user_additions(additions_path)

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

<<<<<<< HEAD
<<<<<<< HEAD
        # If Benders, create processes for subproblems optimization
        if isa(solution_algorithm(case), Benders)
            if case.settings.BendersSettings[:Distributed]
                number_of_subproblems = sum(length(system.time_data[:Electricity].subperiods) for system in case.systems)
                start_distributed_processes!(number_of_subproblems, case_path)
            end
=======
    (case, solution) = solve_case(case, optimizer, use_preallocation)
=======
    (case, solution) = solve_case(case, optimizer; use_preallocation=use_preallocation)
>>>>>>> eccf6566 (preallocation updates to benders/operations, benders/planning, generate_model, myopic, solver, and run_tools)

    if length(case.systems) ≥ 1
        case_path = create_output_path(case.systems[1], case_path)
    end
    write_outputs(case_path, case, solution)

    # If Benders, delete processes
    if isa(solution_algorithm(case), Benders)
        if case.settings.BendersSettings[:Distributed] && length(workers()) > 1
            rmprocs.(workers())
>>>>>>> ed7d4fc4 (Updated variable and constraint preallocation)
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
            if case.settings.BendersSettings[:Distributed] && length(workers()) > 1
                rmprocs.(workers())
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
    rmprocs(workers())  # Ensure all processes are removed
end