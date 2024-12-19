Base.@kwdef mutable struct BalanceConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::BalanceConstraint, v::AbstractVertex, model::Model)

Add a balance constraint to the vertex `v`. 

- If `v` is a `Node`, a demand balance constraint is added. 
- If `v` is a `Transformation`, this constraint ensures that the stoichiometric equations linking the input and output flows are correctly balanced.

```math
\begin{aligned}
    \sum_{\substack{i\  \in \ \text{balance\_eqs\_ids(v)}, \\ t\  \in \ \text{time\_interval(v)}} } \text{balance\_eq(v, i, t)} = 0.0
\end{aligned}
```
"""
function add_model_constraint!(ct::BalanceConstraint, v::AbstractVertex, model::Model)

    ct.constraint_ref = @constraint(
        model,
        [i in balance_ids(v), t in time_interval(v)],
        get_balance(v, i, t) == 0.0
    )

    return nothing
end
