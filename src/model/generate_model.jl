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

function generate_model(stages::Stages)
    generate_model(stages, expansion_mode(stages))
end

# Single stage model
function generate_model(stages::Stages, ::SingleStage)
    return generate_model(stages.systems[1])
end

# Multistage model with perfect foresight
function generate_model(stages::Stages, ::PerfectForesight)

    systems = stages.systems
    settings = stages.settings

    @info("Generating multistage model with perfect foresight")

    start_time = time();

    model = Model()

    @variable(model, vREF == 1)

    number_of_stages = length(systems)

    fixed_cost = Dict()
    variable_cost = Dict()

    for s in 1:number_of_stages

        @info(" -- Stage $s")

        model[:eFixedCost] = AffExpr(0.0)
        model[:eVariableCost] = AffExpr(0.0)

        @info(" -- Adding linking variables")
        add_linking_variables!(systems[s], model) 

        @info(" -- Defining available capacity")
        define_available_capacity!(systems[s], model)

        @info(" -- Generating planning model")
        planning_model!(systems[s], model)

        @info(" -- Including age-based retirements")
        add_age_based_retirements!.(systems[s].assets, model)

        if s < number_of_stages
            @info(" -- Available capacity in stage $(s) is being carried over to stage $(s+1)")
            carry_over_capacities!(systems[s+1], systems[s])
        end

        @info(" -- Generating operational model")
        operation_model!(systems[s], model)

        fixed_cost[s] = model[:eFixedCost];
	    unregister(model,:eFixedCost)

        variable_cost[s] = model[:eVariableCost];
        unregister(model,:eVariableCost)

    end

    #The settings are the same in all stages, we have a single settings file that gets copied into each system struct
    stage_lengths = collect(settings.StageLengths)

    wacc = settings.WACC

    cum_years = [sum(stage_lengths[i] for i in 1:s-1; init=0) for s in 1:number_of_stages];

    discount_factor = 1 ./ ( (1 + wacc) .^ cum_years)

    @expression(model, eDiscountedFixedCost[s in 1:number_of_stages], discount_factor[s] * fixed_cost[s])

    @expression(model, eFixedCost, sum(eDiscountedFixedCost[s] for s in 1:number_of_stages))

    opexmult = [sum([1 / (1 + wacc)^(i - 1) for i in 1:stage_lengths[s]]) for s in 1:number_of_stages]

    @expression(model, eDiscountedVariableCost[s in 1:number_of_stages], discount_factor[s] * opexmult[s] * variable_cost[s])

    @expression(model, eVariableCost, sum(eDiscountedVariableCost[s] for s in 1:number_of_stages))

    @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

    @info(" -- Model generation complete, it took $(time() - start_time) seconds")

    return model
    
end