Base.@kwdef mutable struct MustRunConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::MustRunConstraint, e::Edge, model::Model)

Add a must run constraint to the edge `e`. The functional form of the constraint is:

```math
\begin{aligned}
    \text{flow(e, t)} = \text{availability(e, t)} \times \text{capacity(e)}
\end{aligned}
```
for each time `t` in `time_interval(e)` for the edge `e`.

!!! note "Must run constraint"
    This constraint is available only for unidirectional edges.
"""
function add_model_constraint!(ct::MustRunConstraint, e::Edge, model::Model)
    if e.unidirectional

        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            flow(e, t) == availability(e, t) * capacity(e)
        )
    else
         @warn "MustRunConstraint required for an edge that is not unidirectional so Macro will not create this constraint"
    end

    return nothing
end