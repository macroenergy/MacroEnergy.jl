
Base.@kwdef mutable struct StorageSymmetricCapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(
    ct::StorageSymmetricCapacityConstraint,
    g::Storage,
    model::Model,
)
    e_discharge = g.discharge_edge
    e_charge = g.charge_edge

    ct.constraint_ref = @constraint(
        model,
        [t in time_interval(g)],
        flow(e_discharge, t) + flow(e_charge, t) <= capacity(e_discharge)
    )


    return nothing
end
