function solve_stages(stages::Stages, opt::O) where O <: Union{Optimizer, Dict{Symbol, Dict{Symbol, Any}}}
    solve_stages(stages, opt, expansion_mode(stages),solution_algorithm(stages))
end

####### single stage expansion and perfect foresight expansion #######
# share the same model generation and optimization workflow
function solve_stages(stages::Stages, opt::Optimizer, expansion::T, ::Monolithic) where T <: Union{SingleStage, PerfectForesight}

    @info("*** Running $(expansion) simulation ***")
    
    model = generate_model(stages, expansion)

    set_optimizer(model, opt)

    # for single stage and perfect foresight there is only one model
    # scale constraints if the flag is true in the first system
    if stages.systems[1].settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(model)
    end

    optimize!(model)

    return (stages, model)
end

####### myopic expansion #######
function solve_stages(stages::Stages, opt::Optimizer, ::Myopic, ::Monolithic)

    @info("*** Running myopic simulation ***")
    
    systems = stages.systems
    number_of_stages = length(systems)
    @assert number_of_stages > 0    # check that there are stages
    
    models = Vector{Model}(undef, number_of_stages)
    for s in 1:number_of_stages
        @info(" -- Generating model for stage $(s)")
        model = generate_model(systems[s]) # run single stage model

        @info(" -- Including age-based retirements")
        add_age_based_retirements!.(systems[s].assets, model)

        set_optimizer(model, opt)

        scale_constraints!(systems[s], model)

        optimize!(model)

        if s < number_of_stages
            @info(" -- Final capacity in stage $(s) is being carried over to stage $(s+1)")
            carry_over_capacities!(systems[s+1], systems[s], perfect_foresight=false)
        end

        models[s] = model
    end

    return (stages, models)
end

####### Benders decomposition algorithm: solves either multistage with perfect foresight or single stage models #######
function solve_stages(stages::Stages, opt::Dict{Symbol, Dict{Symbol, Any}}, expansion::T, ::Benders) where T <: Union{SingleStage, PerfectForesight}

    @info("*** Running $(expansion) simulation with Benders decomposition ***")
    bd_setup = stages.settings.BendersSettings
    systems = stages.systems;

    # Decomposed system
    systems_decomp = generate_decomposed_system(systems);

    planning_problem,linking_variables = initialize_planning_problem!(stages,opt[:planning])

    subproblems, linking_variables_sub = initialize_subproblems!(systems_decomp,opt[:subproblems],bd_setup[:Distributed],bd_setup[:IncludeAutomaticSlackPenalty])

    results = MacroEnergySolvers.benders(planning_problem, linking_variables, subproblems, linking_variables_sub, Dict(pairs(bd_setup)))

    return (stages, BendersResults(results, subproblems))
end

