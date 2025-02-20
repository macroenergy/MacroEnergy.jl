Base.@kwdef mutable struct CO2CapConstraint <: PolicyConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

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
            base_name = "v" * string(ct_type) * "_Slack_$(id(n))_stage$(stage_index(n))"
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
