
Base.@kwdef mutable struct StorageCapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(
    ct::StorageCapacityConstraint,
    g::AbstractTransform,
    model::Model,
)

    if has_storage(g)
        ct.constraint_ref = @constraint(
            model,
            [t in timesteps(g)],
            storage_level(g,t) <= capacity_storage(g)
        )
    else
        @warn "StorageCapacityConstraint required for a transformation that does not have storage so MACRO will not create this constraint"
    end

    return nothing
end