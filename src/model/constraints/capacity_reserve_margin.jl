Base.@kwdef mutable struct CapacityReserveMarginConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::CapacityReserveMarginConstraint, system::System, model::Model)
    
    ct.constraint_ref = @constraint(
            model,
            [k in keys(system.settings.CapacityReserveMargin)],
            model[:eCapacityReserveMargin][k] >= 0.0
        )

    return nothing
end