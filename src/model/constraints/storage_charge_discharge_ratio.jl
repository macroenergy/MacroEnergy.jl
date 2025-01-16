Base.@kwdef mutable struct StorageChargeDischargeRatioConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(
    ct::StorageChargeDischargeRatioConstraint,
    g::Storage,
    model::Model,
)

    ct.constraint_ref = @constraint(model,
        charge_discharge_ratio(g)*capacity(g.discharge_edge) == capacity(g.charge_edge)
        )

    return nothing
end