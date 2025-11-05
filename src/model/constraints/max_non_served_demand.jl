Base.@kwdef mutable struct MaxNonServedDemandConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::MaxNonServedDemandConstraint, n::Node, model::Model)

Add a max non-served demand constraint to the node `n`. The functional form of the constraint is:

```math
\begin{aligned}
    \sum_{s\ \in\ \text{segments\_nsd(n)}} \text{non\_served\_demand(n, s, t)} \leq \text{demand(n, t)}
\end{aligned}
```
for each time `t` in `time_interval(n)` for the node `n`.
"""
function add_model_constraint!(ct::MaxNonServedDemandConstraint, n::Node, model::Model)
    if !isempty(non_served_demand(n))
        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(n)],
            sum(non_served_demand(n, s, t) for s in segments_non_served_demand(n)) <=
            demand(n, t)
        )
    else
        @warn "MaxNonServedDemandConstraint required for a node that does not have a non-served demand variable so Macro will not create this constraint"
    end

end
