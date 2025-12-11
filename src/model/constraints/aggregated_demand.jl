Base.@kwdef mutable struct AggregatedDemandConstraint <: PolicyConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::AggregatedDemandConstraint, n::Node{T}, model::Model) where {T}

Constraint for the total commodity flow into `n` to be greater than or equal to the value of the `rhs_policy` for the `AggregatedDemand` constraint type.

The functional form of the constraint is:

```math
\begin{aligned}
    \sum_{t \in \text{time\_interval(n)}} \text{demand_flow(n, t)} \geq \text{rhs\_policy(n)}
\end{aligned}
```
"Demand Flow" in the above equation is the net balance commodity flow into the demand node `n`.
"""
function add_model_constraint!(ct::AggregatedDemandConstraint, n::Node{T}, model::Model) where {T}
    ct_type = typeof(ct)

    subperiod_balance = @expression(model, [w in subperiod_indices(n)], 0 * model[:vREF])

    for t in time_interval(n)
        w = current_subperiod(n,t)
        add_to_expression!(
            subperiod_balance[w],
            subperiod_weight(n, w),
            get_balance(n, :demand_flow, t),
        )
    end

    ct.constraint_ref = @constraint(
        model,
        [w in subperiod_indices(n)],
        subperiod_balance[w] >=
        n.policy_budgeting_vars[Symbol(string(ct_type) * "_Budget")][w]
    )


end

