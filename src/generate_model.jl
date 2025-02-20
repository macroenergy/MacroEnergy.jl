function generate_model(system::System)

    @info("Generating model")

    start_time = time();

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

    @info(" -- Model generation complete. It took $(round(time() - start_time, digits=2)) seconds")

    return model

end


function planning_model!(system::System, model::Model)

    planning_model!.(system.locations, Ref(model))

    planning_model!.(system.assets, Ref(model))

    add_constraints_by_type!(system, model, PlanningConstraint)

end


function operation_model!(system::System, model::Model)

    operation_model!.(system.locations, Ref(model))

    operation_model!.(system.assets, Ref(model))

    add_constraints_by_type!(system, model, OperationConstraint)

end

function planning_model!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        planning_model!(getfield(a, t), model)
    end
    return nothing
end

function operation_model!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        operation_model!(getfield(a, t), model)
    end
    return nothing
end

function add_linking_variables!(system::System, model::Model)

    add_linking_variables!.(system.locations, model)

    add_linking_variables!.(system.assets, model)

end

function add_linking_variables!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        add_linking_variables!(getfield(a, t), model)
    end
end

function define_available_capacity!(system::System, model::Model)

    define_available_capacity!.(system.locations, model)

    define_available_capacity!.(system.assets, model)

end

function define_available_capacity!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        define_available_capacity!(getfield(a, t), model)
    end
end

function generate_multistage_model_foresight(system_vec::Vector{System})

    @info("Generating multistage model with perfect foresight")

    start_time = time();

    model = Model()

    @variable(model, vREF == 1)

    model[:eFixedCost] = AffExpr(0.0)

    model[:eVariableCost] = AffExpr(0.0)

    number_of_stages = length(system_vec);

    fixed_cost = Dict();

    variable_cost = Dict();

    for s in 1:number_of_stages

        @info(" -- Stage $s")

        model[:eFixedCost] = AffExpr(0.0)

        model[:eVariableCost] = AffExpr(0.0)
    
        if s>1
            @info(" -- Initializing capacity variables and expressions in stage $s based on those in stage $(s-1)")
            initialize_stage_capacities!(system_vec[s],system_vec[s-1])
        end

        @info(" -- Adding linking variables")
        add_linking_variables!(system_vec[s], model) 

        @info(" -- Defining available capacity")
        define_available_capacity!(system_vec[s], model)

        @info(" -- Generating planning model")
        planning_model!(system_vec[s], model)

        @info(" -- Including age-based retirements")
        add_age_based_retirements!.(system_vec[s].assets, model)

        @info(" -- Generating operational model")
        operation_model!(system_vec[s], model)

        fixed_cost[s] = model[:eFixedCost];

        variable_cost[s] = model[:eVariableCost];

	    unregister(model,:eFixedCost)

        unregister(model,:eVariableCost)
    end

    @expression(model,eFixedCost[s in 1:number_of_stages],fixed_cost[s])

    @expression(model,eVariableCost[s in 1:number_of_stages],variable_cost[s])

    #The settings are the same in all stages, we have a single settings file that gets copied into each system struct
    stage_lengths = collect(system_vec[1].settings.StageLengths)
    wacc = system_vec[1].settings.WACC

    cum_years = [sum(stage_lengths[i] for i in 1:s-1; init=0) for s in 1:number_of_stages];

    discount_factor = 1 ./ ( (1 + wacc) .^ cum_years)

    opexmult = [sum([1 / (1 + wacc)^(i - 1) for i in 1:stage_lengths[s]]) for s in 1:number_of_stages]

    @expression(model, eObj, sum(discount_factor[s] * ( model[:eFixedCost][s] + opexmult[s] * model[:eVariableCost][s] ) for s in 1:number_of_stages))

    @objective(model, Min, eObj)

    @info(" -- Model generation complete, it took $(time() - start_time) seconds")

    return model
    
end