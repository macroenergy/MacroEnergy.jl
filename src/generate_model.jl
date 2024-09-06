function generate_model(system::System)

    model = Model()

    @variable(model, vREF == 1)

    model[:eFixedCost] = AffExpr(0.0)

    model[:eVariableCost] = AffExpr(0.0)

    add_planning_variables!(system, model)

    add_operation_variables!(system,model)

    add_all_model_constraints!(system,model)

    @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

    return model

end


function add_planning_variables!(system::System, model::Model)

    add_planning_variables!.(system.locations, Ref(model))

    add_planning_variables!.(system.assets, Ref(model))
    
end

function add_operation_variables!(system::System,model::Model)

    add_operation_variables!.(system.locations, Ref(model))

    add_operation_variables!.(system.assets, Ref(model))
    
end

function add_planning_variables!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        add_planning_variables!(getfield(a,t), model)
    end
    return nothing
end

function add_operation_variables!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        add_operation_variables!(getfield(a,t), model)
    end
    return nothing
end



# function generate_model(system::System)
#     # objects = [system.locations..., system.assets...]
#     objects = MacroObject[]
#     for node in system.locations
#         push!(objects, node)
#     end
#     for asset in system.assets
#         component_names = fieldnames(typeof(asset))
#         for name in component_names
#             push!(objects, getfield(asset, name))
#         end
#     end
#     return generate_model(objects)
# end