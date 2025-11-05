Base.@kwdef mutable struct CapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::CapacityConstraint, e::Edge, model::Model)

Add a capacity constraint to the edge `e`. If the edge is unidirectional, the functional form of the constraint is:

```math
\begin{aligned}
    \text{flow(e, t)} \leq \text{availability(e, t)} \times \text{capacity(e)}
\end{aligned}
```

If the edge is bidirectional, the constraint is:

```math
\begin{aligned}
    i \times \text{flow(e, t)} \leq \text{availability(e, t)} \times \text{capacity(e)}
\end{aligned}
```

for each time `t` in `time_interval(e)` for the edge `e` and each `i` in `{0, 1}`. The function `availability` returns the time series of the capacity factor of the edge at time `t`.
"""
function add_model_constraint!(ct::CapacityConstraint, e::Edge, model::Model)

    if e.unidirectional

        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            flow(e, t) <= availability(e, t) * capacity(e)
        )
    else
        ct.constraint_ref = @constraint(
            model,
            [i in [-1, 1], t in time_interval(e)],
            i * flow(e, t) <= availability(e, t) * capacity(e)
        )
    end

    return nothing

end

@doc raw"""
    add_model_constraint!(ct::CapacityConstraint, e::EdgeWithUC, model::Model)

Add a capacity constraint to the edge `e` with unit commitment. If the edge is unidirectional, the functional form of the constraint is:
```math
\begin{aligned}
    \sum_{t \in \text{time\_interval(e)}} \text{flow(e, t)} \leq \text{availability(e, t)} \times \text{capacity(e)} \times \text{ucommit(e, t)}
\end{aligned}
```

If the edge is bidirectional, the constraint is:

```math
\begin{aligned}
    i \times \text{flow(e, t)} \leq \text{availability(e, t)} \times \text{capacity(e)} \times \text{ucommit(e, t)}
\end{aligned}
```

for each time `t` in `time_interval(e)` for the edge `e` and each `i` in `[-1, 1]`. The function `availability` returns the time series of the availability of the edge at time `t`.
"""
function add_model_constraint!(ct::CapacityConstraint, e::EdgeWithUC, model::Model)

    if e.unidirectional

        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            flow(e, t) <= availability(e, t) * capacity_size(e) * ucommit(e, t)
        )
    else
        ct.constraint_ref = @constraint(
            model,
            [i in [-1, 1], t in time_interval(e)],
            i * flow(e, t) <= availability(e, t) * capacity_size(e) * ucommit(e, t)
        )
    end

    return nothing

end
