Base.@kwdef mutable struct MaxNonServedDemandConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(
    ct::MaxNonServedDemandConstraint,
    n::AbstractNode,
    model::Model,
)
    if haskey(n.operation_vars,:non_served_demand)
        ct.constraint_ref = @constraint(
            model,
            [t in timesteps(n)],
            sum(non_served_demand(n,s,t) for s in segments_non_served_demand(n)) <= demand(n,t)
        )
    else
        @warn "MaxNonServedDemandConstraint required for a node that does not have a non-served demand variable so MACRO will not create this constraint"
    end

end
