function solve_stages(stages::Stages, opt::O) where O <: Union{Optimizer, Dict{Symbol, Dict{Symbol, Any}}}
    solve_stages(stages, opt, solution_algorithm(stages))
end

function solve_stages(stages::Stages, opt::Optimizer, ::Monolithic)

    @info("*** Running simulation with monolithic solver ***")
    
    model = generate_model(stages)

    set_optimizer(model, opt)

    # For monolithic solution there is only one model
    # scale constraints if the flag is true in the first system
    if stages.systems[1].settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(model)
    end

    optimize!(model)

    return (stages, model)
end

####### myopic expansion #######
function solve_stages(stages::Stages, opt::Optimizer, ::Myopic)

    @info("*** Running simulation with myopic iteration ***")
    
    models = run_myopic_iteration!(stages,opt)

    return (stages, MyopicResults(models))
end

####### Benders decomposition algorithm #######
function solve_stages(stages::Stages, opt::Dict{Symbol, Dict{Symbol, Any}}, ::Benders)

    @info("*** Running simulation with Benders decomposition ***")
    bd_setup = stages.settings.BendersSettings
    systems = stages.systems;

    # Decomposed system
    systems_decomp = generate_decomposed_system(systems);

    planning_problem = initialize_planning_problem!(stages,opt[:planning])

    subproblems, linking_variables_sub = initialize_subproblems!(systems_decomp,opt[:subproblems],bd_setup[:Distributed],bd_setup[:IncludeSubproblemSlacksAutomatically])

    results = MacroEnergySolvers.benders(planning_problem, subproblems, linking_variables_sub, Dict(pairs(bd_setup)))

    update_with_planning_solution!(stages, results.planning_sol.values)

    return (stages, BendersResults(results, subproblems))
end
