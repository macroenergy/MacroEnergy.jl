Base.@kwdef mutable struct StorageCapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::StorageCapacityConstraint, g::AbstractStorage, model::Model)

Add a storage capacity constraint to the storage `g`. The functional form of the constraint is:

```math
\begin{aligned}
    \text{storage\_level(g, t)} \leq \text{capacity(g)}
\end{aligned}
```
for each time `t` in `time_interval(g)` for the storage `g`.
"""
function add_model_constraint!(ct::StorageCapacityConstraint, g::AbstractStorage, model::Model)

    ct.constraint_ref = @constraint(
        model,
        [t in time_interval(g)],
        storage_level(g, t) <= capacity(g)
    )

    return nothing
end
