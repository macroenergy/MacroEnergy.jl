Base.@kwdef mutable struct MinFlowConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::MinFlowConstraint, e::Edge, model::Model)

Add a min flow constraint to the edge `e`. The functional form of the constraint is:

```math
\begin{aligned}
    \text{flow(e, t)} \geq \text{min\_flow\_fraction(e)} \times \text{capacity(e)}
\end{aligned}
```
for each time `t` in `time_interval(e)` for the edge `e`. 
!!! note
    This constraint is available only for unidirectional edges.
"""
function add_model_constraint!(ct::MinFlowConstraint, e::Edge, model::Model)
    if e.unidirectional
        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            flow(e, t) >= min_flow_fraction(e) * capacity(e)
        )
    else
        warning("Min flow constraints are available only for unidirectional edges")
    end

    return nothing
end

@doc raw"""
    add_model_constraint!(ct::MinFlowConstraint, e::EdgeWithUC, model::Model)

Add a min flow constraint to the edge `e` with unit commitment. The functional form of the constraint is:

```math
\begin{aligned}
    \text{flow(e, t)} \geq \text{min\_flow\_fraction(e)} \times \text{capacity\_size(e)} \times \text{ucommit(e, t)}
\end{aligned}
```
for each time `t` in `time_interval(e)` for the edge `e`.
!!! note
    This constraint is available only for unidirectional edges.
"""
function add_model_constraint!(ct::MinFlowConstraint, e::EdgeWithUC, model::Model)
    if e.unidirectional
        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            flow(e, t) >= min_flow_fraction(e) * capacity_size(e) * ucommit(e, t)
        )
    else
        warning("Min flow constraints are available only for unidirectional edges")
    end

    return nothing
end
