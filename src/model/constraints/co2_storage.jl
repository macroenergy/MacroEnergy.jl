Base.@kwdef mutable struct CO2StorageConstraint <: PolicyConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::CO2StorageConstraint, n::Node{CO2Captured}, model::Model)
    ct_type = typeof(ct)

    subperiod_balance = @expression(model, [w in subperiod_indices(n)], 0 * model[:vREF])

    for t in time_interval(n)
        w = current_subperiod(n,t)
        add_to_expression!(
            subperiod_balance[w],
            subperiod_weight(n, w),
            get_balance(n, :co2_storage, t),
        )
    end

    ct.constraint_ref = @constraint(
        model,
        [w in subperiod_indices(n)],
        subperiod_balance[w] <=
        n.policy_budgeting_vars[Symbol(string(ct_type) * "_Budget")][w]
    )
end
