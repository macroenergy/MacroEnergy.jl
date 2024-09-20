function generate_model(system::System)

    @info("Starting model generation")
    model = Model()

    @variable(model, vREF == 1)

    model[:eFixedCost] = AffExpr(0.0)

    model[:eVariableCost] = AffExpr(0.0)

    @info("Adding linking variables")
    add_linking_variables!(system, model) 

    @info("Generating planning model")
    planning_model!(system, model)

    @info("Generating operational model")
    operation_model!(system, model)

    @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

    @info("Model generation complete")
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
