Base.@kwdef mutable struct BalanceConstraint <:OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(
    ct::BalanceConstraint,
    v::AbstractVertex,
    model::Model,
)

    ct.constraint_ref =
        @constraint(model, [i in balance_ids(v), t in time_interval(v)], get_balance(v,i,t) == 0.0)

    return nothing
end
