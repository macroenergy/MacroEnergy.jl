function solve_case(case::Case, opt::O) where O <: Union{Optimizer, Dict{Symbol, Dict{Symbol, Any}}}
    solve_case(case, opt, solution_algorithm(case))
end

function solve_case(case::Case, opt::Optimizer, ::Monolithic)

    @info("*** Running simulation with monolithic solver ***")
    
    model = generate_model(case)

    set_optimizer(model, opt)

    # For monolithic solution there is only one model
    # scale constraints if the flag is true in the first system
    if case.systems[1].settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(model)
    end

    optimize!(model)

    return (case, model)
end

####### myopic expansion #######
function solve_case(case::Case, opt::Optimizer, ::Myopic)

    @info("*** Running simulation with myopic iteration ***")
    
    models = run_myopic_iteration!(case,opt)

    return (case, MyopicResults(models))
end

####### Benders decomposition algorithm #######
function solve_case(case::Case, opt::Dict{Symbol, Dict{Symbol, Any}}, ::Benders)

    @info("*** Running simulation with Benders decomposition ***")
    bd_setup = get_settings(case).BendersSettings
    periods = get_periods(case);

    # Decomposed system
    periods_decomp = generate_decomposed_system(periods);

    planning_problem = initialize_planning_problem!(case,opt[:planning])

    subproblems, linking_variables_sub = initialize_subproblems!(periods_decomp,opt[:subproblems],bd_setup[:Distributed],bd_setup[:IncludeSubproblemSlacksAutomatically])

    results = MacroEnergySolvers.benders(planning_problem, subproblems, linking_variables_sub, Dict(pairs(bd_setup)))

    update_with_planning_solution!(case, results.planning_sol.values)

    return (case, BendersResults(results, subproblems))
end
