Base.@kwdef mutable struct StorageMaxDurationConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::StorageMaxDurationConstraint, g::AbstractStorage, model::Model)

Add a storage max duration constraint to the storage `g`. The functional form of the constraint is:

```math
\begin{aligned}
    \text{capacity(g)} \leq \text{max\_duration(g)} \times \text{capacity(discharge\_edge(g))}
\end{aligned}
```

!!! note "Storage max duration constraint"
    This constraint is only applied if the maximum duration is greater than 0.
"""
function add_model_constraint!(ct::StorageMaxDurationConstraint, g::AbstractStorage, model::Model)
    e = discharge_edge(g)

    if max_duration(g) > 0
        ct.constraint_ref =
            @constraint(model, capacity(g) <= max_duration(g) * capacity(e))
    end

    return nothing
end


Base.@kwdef mutable struct StorageMinDurationConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::StorageMinDurationConstraint, g::AbstractStorage, model::Model)

Add a storage min duration constraint to the storage `g`. The functional form of the constraint is:

```math
\begin{aligned}
    \text{capacity(g)} \geq \text{min\_duration(g)} \times \text{capacity(discharge\_edge(g))}
\end{aligned}
```

!!! note "Storage min duration constraint"
    This constraint is only applied if the minimum duration is greater than 0.
"""
function add_model_constraint!(ct::StorageMinDurationConstraint, g::AbstractStorage, model::Model)
    e = discharge_edge(g)

    if max_duration(g) > 0
        ct.constraint_ref =
            @constraint(model, capacity(g) >= min_duration(g) * capacity(e))
    end

    return nothing
end
