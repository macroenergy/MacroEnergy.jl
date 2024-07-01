Base.@kwdef mutable struct DemandBalanceConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::DemandBalanceConstraint, n::AbstractNode, model::Model)

    ct.constraint_ref = @constraint(
        model,
        [t in timesteps(n)],
        net_balance(n,t)  == demand(n,t)
    )

end

