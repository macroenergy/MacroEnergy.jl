Base.@kwdef mutable struct CO2CapConstraint <: PolicyConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::CO2CapConstraint, n::Node{CO2}, model::Model)

Constraint the CO2 emissions of CO2 on a CO2 node `n` to be less than or equal to the value of the `rhs_policy` for the `CO2CapConstraint` constraint type.
If the `price_unmet_policy` is also specified, then a slack variable is added to the constraint to allow for the CO2 emissions to exceed the value of the `rhs_policy`, incurring in a penalty cost specified in the `price_unmet_policy` for the `CO2CapConstraint` constraint type.
Please check the example case in the [MacroEnergyExamples.jl repository](https://github.com/macroenergy/MacroEnergyExamples.jl), or the [Macro Input Data](@ref) section of the documentation for more information on how to specify the `rhs_policy` and `price_unmet_policy` for the `CO2CapConstraint` constraint type.

Therefore, the functional form of the constraint is:

```math
\begin{aligned}
    \sum_{t \in \text{time\_interval(n)}} \text{emissions(n, t)} - \text{slack(n)} \leq \text{rhs\_policy(n)}
\end{aligned}
```
"Emissions" in the above equation is the net balance of CO2 flows into and out of the CO2 node `n`.

!!! note "Enabling CO2 emissions for an asset"
    **For modelers**: To allow for an asset to contribute to the CO2 emissions of a CO2 node, the asset must have an "emissions" key in its `balance_data` dictionary. The value of this key should be the `emission_rate` of the asset.
"""
function add_model_constraint!(ct::CO2CapConstraint, n::Node{CO2}, model::Model)
    ct_type = typeof(ct)

    subperiod_balance = @expression(model, [w in subperiod_indices(n)], 0 * model[:vREF])

    for t in time_interval(n)
        w = current_subperiod(n,t)
        add_to_expression!(
            subperiod_balance[w],
            subperiod_weight(n, w),
            get_balance(n, :emissions, t),
        )
    end

    if haskey(price_unmet_policy(n), ct_type)
        n.policy_slack_vars[Symbol(string(ct_type) * "_Slack")] = @variable(
            model,
            [w in subperiod_indices(n)],
            lower_bound = 0.0,
            base_name = "v" * string(ct_type) * "_Slack_$(id(n))_period$(period_index(n))"
        )
        for w in subperiod_indices(n)
            add_to_expression!(
                model[:eVariableCost],
                subperiod_weight(n, w) * price_unmet_policy(n, ct_type),
                n.policy_slack_vars[Symbol(string(ct_type) * "_Slack")][w],
            )

            add_to_expression!(
                subperiod_balance[w],
                -n.policy_slack_vars[Symbol(string(ct_type) * "_Slack")][w],
            )
        end
    end

    ct.constraint_ref = @constraint(
        model,
        [w in subperiod_indices(n)],
        subperiod_balance[w] <=
        n.policy_budgeting_vars[Symbol(string(ct_type) * "_Budget")][w]
    )

end