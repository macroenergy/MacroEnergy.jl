Base.@kwdef mutable struct StorageChargeDischargeRatioConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(
        ct::StorageChargeDischargeRatioConstraint,
        g::AbstractStorage,
        model::Model,
    )

Add a storage charge discharge ratio constraint to the storage `g`. The functional form of the constraint is:

```math
\begin{aligned}
    \text{charge\_discharge\_ratio(g)} \times \text{capacity(g.discharge\_edge)} = \text{capacity(g.charge\_edge)}
\end{aligned}
```
"""
function add_model_constraint!(
    ct::StorageChargeDischargeRatioConstraint,
    g::AbstractStorage,
    model::Model,
)

    ct.constraint_ref = @constraint(model,
        charge_discharge_ratio(g)*capacity(g.discharge_edge) == capacity(g.charge_edge)
        )

    return nothing
end