Base.@kwdef mutable struct StoichiometryBalanceConstraint <:OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(
    ct::StoichiometryBalanceConstraint,
    g::AbstractTransform,
    model::Model,
)

    ct.constraint_ref =
        @constraint(model, [i in stoichiometry_balance_names(g), t in timesteps(g)], stoichiometry_balance(g,i,t) == 0.0)

    return nothing
end

