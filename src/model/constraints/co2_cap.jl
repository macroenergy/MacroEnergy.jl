Base.@kwdef mutable struct CO2CapConstraint <:PolicyConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::CO2CapConstraint,
    n::Node{CO2},
    model::Model
)
    ct_type = typeof(ct);

    subperiod_net_balance = @expression(model,[w in subperiods(n)],0*model[:vREF]);

    for t in timesteps(n)
        w = current_subperiod(n,t);
        add_to_expression!(subperiod_net_balance[w],subperiod_weight(n,w),net_balance(n,t));
    end

    if haskey(price_unmet_policy(n),ct_type)
        n.operation_vars[Symbol(string(ct_type)*"_Slack")] = @variable(
            model,
            [w in subperiods(n)],
            lower_bound = 0.0,
            base_name = "v"*string(ct_type)*"_Slack_$(get_id(n))"
        )
        for w in subperiods(n)
            add_to_expression!(model[:eVariableCost], subperiod_weight(n,w)*price_unmet_policy(n,ct_type),n.operation_vars[Symbol(string(ct_type)*"_Slack")][w])

            add_to_expression!(subperiod_net_balance[w], -n.operation_vars[Symbol(string(ct_type)*"_Slack")][w])
        end
    end
    
    ct.constraint_ref = @constraint(model, 
    [w in subperiods(n)], 
    subperiod_net_balance[w] <= n.planning_vars[Symbol(string(ct_type)*"_Budget")][w])


end