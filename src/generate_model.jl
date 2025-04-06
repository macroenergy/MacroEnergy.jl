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

    # Add retrofit constraints at a system level - need to move later
    # retrofit_ids = get_unique_retrofit_ids(system)
    # @expression(model, eRetrofittedCapByRetroId[id in retrofit_ids], 0 * model[:vREF])
    # @expression(model, eRetrofitCapByRetroId[id in retrofit_ids], 0 * model[:vREF])

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