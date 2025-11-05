
Base.@kwdef mutable struct StorageSymmetricCapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(
        ct::StorageSymmetricCapacityConstraint,
        g::AbstractStorage,
        model::Model,
    )

Add a storage symmetric capacity constraint to the storage `g`. The functional form of the constraint is:

```math
\begin{aligned}
    \text{flow(e\_discharge, t)} + \text{flow(e\_charge, t)} \leq \text{capacity(e\_discharge)}
\end{aligned}
```
"""
function add_model_constraint!(
    ct::StorageSymmetricCapacityConstraint,
    g::AbstractStorage,
    model::Model,
)
    e_discharge = g.discharge_edge
    e_charge = g.charge_edge

    ct.constraint_ref = @constraint(
        model,
        [t in time_interval(g)],
        flow(e_discharge, t) + flow(e_charge, t) <= capacity(e_discharge)
    )

    return nothing
end
