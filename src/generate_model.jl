function generate_model(system::Vector{T}) where T<:Union{Node, Edge, AbstractAsset}

    model = Model()

    @variable(model, vREF == 1)

    model[:eFixedCost] = AffExpr(0.0)

    model[:eVariableCost] = AffExpr(0.0)

    add_planning_variables!.(system, Ref(model))

    add_operation_variables!.(system, Ref(model))

    add_all_model_constraints!.(system, Ref(model))

    @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

    return model

end
