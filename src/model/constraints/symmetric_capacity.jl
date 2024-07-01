
Base.@kwdef mutable struct SymmetricCapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(
    ct::SymmetricCapacityConstraint,
    g::AbstractTransform,
    model::Model,
)
    if has_storage(g)
        e_discharge = g.TEdges[g.discharge_edge]
        e_charge = g.TEdges[g.charge_edge]
        ct.constraint_ref = @constraint(
            model,
            [t in timesteps(g)],
            flow(e_discharge,t) + flow(e_charge,t) <= capacity(e_discharge)
        )
    else
        @warn "SymmetricCapacityConstraint required for a transformation that does not have storage so MACRO will not create this constraint"
    end

    return nothing
end
