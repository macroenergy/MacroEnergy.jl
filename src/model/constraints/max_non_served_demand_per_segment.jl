Base.@kwdef mutable struct MaxNonServedDemandPerSegmentConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(
    ct::MaxNonServedDemandPerSegmentConstraint,
    n::Node,
    model::Model,
)
    if !isempty(non_served_demand(n))
        ct.constraint_ref = @constraint(
            model,
            [s in segments_non_served_demand(n), t in time_interval(n)],
            non_served_demand(n,s,t) <= max_non_served_demand(n,s) * demand(n,t)
        )
    else
        @warn "MaxNonServedDemandPerSegmentConstraint required for a node that does not have a non-served demand variable so MACRO will not create this constraint"
    end

end
