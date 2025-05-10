struct MyopicResults
    models::Vector{Model}
end

function run_myopic_iteration!(stages::Stages, opt::Optimizer)
    systems = stages.systems
    number_of_stages = length(systems)

    models = Vector{Model}(undef, number_of_stages)
    for (stage_idx,system) in enumerate(systems)
        @info(" -- Generating model for stage $(stage_idx)")
        model = Model()

        @variable(model, vREF == 1)

        model[:eFixedCost] = AffExpr(0.0)

        model[:eVariableCost] = AffExpr(0.0)

        @info(" -- Adding linking variables")
        add_linking_variables!(system, model) 

        @info(" -- Defining available capacity")
        define_available_capacity!(system, model)

        @info(" -- Generating planning model")
        planning_model!(system, model)

        @info(" -- Generating operational model")
        operation_model!(system, model)

        @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

        @info(" -- Including age-based retirements")
        add_age_based_retirements!.(system.assets, model)

        set_optimizer(model, opt)

        scale_constraints!(system, model)

        optimize!(model)

        if stage_idx < number_of_stages
            @info(" -- Final capacity in stage $(stage_idx) is being carried over to stage $(stage_idx+1)")
            carry_over_capacities!(systems[stage_idx+1], system, perfect_foresight=false)
        end

        models[stage_idx] = model
    end

    return models
end