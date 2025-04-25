# Monolithic
function run_case(
    case_path::AbstractString=@__DIR__;
    lazy_load::Bool=true,
    # Monolithic
    optimizer::DataType=HiGHS.Optimizer,
    optimizer_env::Any=missing,
    optimizer_attributes::Tuple=("BarConvTol" => 1e-3, "Crossover" => 0, "Method" => 2),
    # Benders
    planning_optimizer::DataType=HiGHS.Optimizer,
    subproblem_optimizer::DataType=HiGHS.Optimizer,
    planning_optimizer_attributes::Tuple=("BarConvTol" => 1e-3, "Crossover" => 0, "Method" => 2),
    subproblem_optimizer_attributes::Tuple=("BarConvTol" => 1e-3, "Crossover" => 0, "Method" => 2)
)
    @info("Running case at $(case_path)")

    stages = load_stages(case_path; lazy_load=lazy_load)

    # Create optimizer based on solution algorithm
    optimizer = if isa(solution_algorithm(stages), Monolithic)
        create_optimizer(optimizer, optimizer_env, optimizer_attributes)
    elseif isa(solution_algorithm(stages), Benders)
        create_optimizer_benders(planning_optimizer, subproblem_optimizer,
            planning_optimizer_attributes, subproblem_optimizer_attributes)
    else
        error("The solution algorithm is not Monolithic or Benders. Please double check the `SolutionAlgorithm` in the `settings/stage_settings.json` file.")
    end

    # If Benders, create processes for subproblems optimization
    if isa(solution_algorithm(stages), Benders)
        if stages.settings.BendersSettings[:Distributed]
            number_of_processes = sum(length(system.time_data[:Electricity].subperiods) for system in stages.systems)
            start_distributed_processes!(number_of_processes, case_path)
        end
    end

    (stages, solution) = solve_stages(stages, optimizer)

    write_outputs(case_path, stages, solution)

    # If Benders, delete processes
    if isa(solution_algorithm(stages), Benders)
        if stages.settings.BendersSettings[:Distributed]
            rmprocs.(workers())
        end
    end

    return stages.systems, solution
end