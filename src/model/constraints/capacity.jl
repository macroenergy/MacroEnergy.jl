Base.@kwdef mutable struct CapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end


function add_model_constraint!(ct::CapacityConstraint, e::AbstractTransformationEdge, model::Model)


    ct.constraint_ref = @constraint(
            model,
            [t in timesteps(e)],
            flow(e,t) <= capacity_factor(e,t)*capacity(e)
        )
    

    return nothing

end

function add_model_constraint!(ct::CapacityConstraint, e::AbstractTransformationEdgeWithUC, model::Model)

    
    ct.constraint_ref = @constraint(
            model,
            [t in timesteps(e)],
            flow(e,t) <= capacity_factor(e,t)*capacity_size(e)*ucommit(e,t)
        )
 
    return nothing

end


function add_model_constraint!(ct::CapacityConstraint, e::AbstractEdge, model::Model)

    if e.unidirectional
        ct.constraint_ref =
            @constraint(model, [t in timesteps(e)], flow(e,t) <= capacity(e))
    else
        ct.constraint_ref = @constraint(
            model,
            [i in [-1, 1], t in timesteps(e)],
            i * flow(e,t) <= capacity(e)
        )
    end

    return nothing

end