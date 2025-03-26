function solve_stages(stages::Stages, opt::Optimizer)
    solve_stages(stages, opt, algorithm_type(stages))
end

####### single stage algorithm and perfect foresight algorithm #######
# share the same model generation and optimization workflow
function solve_stages(stages::Stages, opt::Optimizer, algorithm::T) where T <: Union{SingleStage, PerfectForesight}

    @info("*** Running $(algorithm) simulation ***")
    
    model = generate_model(stages, algorithm)

    set_optimizer(model, opt)

    scale_constraints!(stages, model)

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
            initialize_stage_capacities!(systems[s+1], systems[s], perfect_foresight=false)
        end

        models[s] = model
    end

    return (stages, models)
end
