function solve_stages(stages::Stages, opt::O) where O <: Union{Optimizer, Dict{Symbol,Optimizer}}
    solve_stages(stages, opt, algorithm_type(stages))
end

####### single stage algorithm and perfect foresight algorithm #######
# share the same model generation and optimization workflow
function solve_stages(stages::Stages, opt::Optimizer, algorithm::T) where T <: Union{SingleStage, PerfectForesight}

    @info("*** Running $(algorithm) simulation ***")
    
    model = generate_model(stages, algorithm)

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

####### myopic algorithm #######
function solve_stages(stages::Stages, opt::Optimizer, ::Myopic)

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
function solve_stages(stages::Stages, opt::Dict{Symbol,Optimizer}, ::Benders)

    @info("*** Running Benders decomposition ***")
    setup = stages.settings.BendersSettings
    system = stages.systems[1]  # FIXME: this will be a vector of systems

    # planning_optimizer = optimizer_with_attributes(()->opt[:planning].optimizer(opt[:planing].optimizer_env), opt[:planning].attributes...)

    # Planning problem
    planning_model, linking_variables = generate_planning_problem(system);
    
    set_optimizer(planning_model, opt[:planning])
    set_silent(planning_model)

    # Decomposed system
    system_decomp = generate_decomposed_system(system);

    number_of_subperiods = length(system_decomp);
    start_distributed_processes!(number_of_subperiods, MacroEnergy, system.data_dirpath)

    subproblems_dict, linking_variables_sub =  initialize_dist_subproblems!(system_decomp, MacroEnergy, opt[:subproblems])

    results = MacroEnergySolvers.benders(planning_model, linking_variables, subproblems_dict, linking_variables_sub, setup)

    return (stages, results)
end

