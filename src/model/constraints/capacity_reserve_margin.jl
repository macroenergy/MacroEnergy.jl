# Typed as an OperationConstraint because the row mixes capacity and flow variables, and all of its
# terms are therefore emitted during the operational model (see add_crm_contribution!). This keeps
# the constraint self-contained within a single model object, so it behaves identically under the
# monolithic, myopic and Benders algorithms. Under Benders it is built inside each operational
# subproblem against that subproblem's linking capacity variables, which is what allows the capacity
# subgradient to reach the optimality cuts.
Base.@kwdef mutable struct CapacityReserveMarginConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::CapacityReserveMarginConstraint, system::System, model::Model)
    crm_exprs = model[:eCapacityReserveMargin]
    # Sorted so that row order is reproducible; iterating a Dict's keys is order-unstable, which
    # would make the generated model differ between runs.
    crm_keys = sort(collect(keys(crm_exprs)))
    ct.constraint_ref = @constraint(
        model,
        [kt in crm_keys],
        crm_exprs[kt] >= 0.0
    )
    return nothing
end
