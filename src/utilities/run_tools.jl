function run_case(
    case_path::AbstractString=@__DIR__; 
    lazy_load::Bool=true, 
    optimizer::DataType=HiGHS.Optimizer, 
    optimizer_env::Any=missing,
    optimizer_attributes::Tuple=("BarConvTol"=>1e-3, "Crossover" => 0, "Method" => 2)
)

    println("###### ###### ######")
    println("Running case at $(case_path)")

    stages = load_stages(case_path; lazy_load=lazy_load)

    optimizer = create_optimizer(optimizer, optimizer_env, optimizer_attributes)

    (stages, model) = solve_stages(stages, optimizer)
    
    write_outputs(case_path, stages, model)

    return stages.systems, model
end

function run_case_benders(
    case_path::AbstractString=@__DIR__; 
    lazy_load::Bool=true, 
    planning_optimizer::DataType=HiGHS.Optimizer, 
    subproblem_optimizer::DataType=HiGHS.Optimizer,
    planning_optimizer_attributes::Tuple=("BarConvTol"=>1e-3, "Crossover" => 0, "Method" => 2),
    subproblem_optimizer_attributes::Tuple=("BarConvTol"=>1e-3, "Crossover" => 0, "Method" => 2)
)

    println("###### ###### ######")
    println("Running case at $(case_path)")

    stages = load_stages(case_path; lazy_load=lazy_load)
    # Check if the solution algorithm is Benders
    if solution_algorithm(stages) != Benders()
        error("The solution algorithm is not Benders. Please use the run_case function instead.")
    end


    benders_optimizers = Dict(
        :planning => Dict(:solver=>planning_optimizer, :attributes=>planning_optimizer_attributes),
        :subproblems => Dict(:solver=>subproblem_optimizer, :attributes=>subproblem_optimizer_attributes),
    )
        

    if stages.settings.BendersSettings[:Distributed]
        number_of_processes = sum(length(system.time_data[:Electricity].subperiods) for system in stages.systems)
        start_distributed_processes!(number_of_processes,case_path)
    end

    (stages, bd_results) = solve_stages(stages, benders_optimizers)

    write_outputs(case_path, stages, bd_results)

    ### Once we do not need the subproblems anymore, we delete the processes
    if stages.settings.BendersSettings[:Distributed]
        rmprocs.(workers())
    end

    return stages.systems, bd_results
end