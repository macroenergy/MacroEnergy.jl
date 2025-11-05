Base.@kwdef mutable struct MaxNonServedDemandPerSegmentConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(
        ct::MaxNonServedDemandPerSegmentConstraint,
        n::Node,
        model::Model,
    )

Add a max non-served demand per segment constraint to the node `n`. The functional form of the constraint is:

```math
\begin{aligned}
    \text{non\_served\_demand(n, s, t)} \leq \text{max\_non\_served\_demand(n, s)} \times \text{demand(n, t)}
\end{aligned}
```
for each segment `s` in `segments_non_served_demand(n)` and each time `t` in `time_interval(n)` for the node `n`. The function `segments_non_served_demand` returns the segments of the non-served demand of the node `n` as defined in the input data `nodes.json`.
"""
function add_model_constraint!(
    ct::MaxNonServedDemandPerSegmentConstraint,
    n::Node,
    model::Model,
)
    if !isempty(non_served_demand(n))
        ct.constraint_ref = @constraint(
            model,
            [s in segments_non_served_demand(n), t in time_interval(n)],
            non_served_demand(n, s, t) <= max_non_served_demand(n, s) * demand(n, t)
        )
    else
        @warn "MaxNonServedDemandPerSegmentConstraint required for a node that does not have a non-served demand variable so Macro will not create this constraint"
    end

end
