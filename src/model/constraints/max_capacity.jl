Base.@kwdef mutable struct MaxCapacityConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end


@doc raw"""
    add_model_constraint!(ct::MaxCapacityConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)

Add a max capacity constraint to the edge or storage `y`. The functional form of the constraint is:

```math
\begin{aligned}
    \text{capacity(y)} \leq \text{max\_capacity(y)}
\end{aligned}
```
"""
function add_model_constraint!(ct::MaxCapacityConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)

    ct.constraint_ref = @constraint(model, capacity(y) <= max_capacity(y))

    return nothing

end
