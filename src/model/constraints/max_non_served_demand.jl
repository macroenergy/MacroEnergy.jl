Base.@kwdef mutable struct MaxNonServedDemandConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(
    ct::MaxNonServedDemandConstraint,
    n::Node,
    model::Model,
)
    if !isempty(non_served_demand(n))
        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(n)],
            sum(non_served_demand(n,s,t) for s in segments_non_served_demand(n)) <= demand(n,t)
        )
    else
        @show  max_non_served_demand(n)
        @warn "MaxNonServedDemandConstraint required for a node that does not have a non-served demand variable so MACRO will not create this constraint"
    end

end
