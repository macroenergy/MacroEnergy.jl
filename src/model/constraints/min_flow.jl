Base.@kwdef mutable struct MinFlowConstraint <:OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(
    ct::MinFlowConstraint,
    e::AbstractTransformationEdge,
    model::Model,
    )

    ct.constraint_ref = @constraint(
            model, 
            [t in timesteps(e)], 
            flow(e,t) >= min_flow_fraction(e)*capacity(e)
            )
    return nothing
end

function add_model_constraint!(
    ct::MinFlowConstraint,
    e::AbstractTransformationEdgeWithUC,
    model::Model,
    )

    ct.constraint_ref = @constraint(
            model, 
            [t in timesteps(e)], 
            flow(e,t) >= min_flow_fraction(e)*capacity_size(e)*ucommit(e,t)
            )
    return nothing

end