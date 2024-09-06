
Base.@kwdef mutable struct StorageCapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(
    ct::StorageCapacityConstraint,
    g::Storage,
    model::Model,
)
    
    ct.constraint_ref = @constraint(
            model,
            [t in time_interval(g)],
            storage_level(g,t) <= capacity_storage(g)
        )

    return nothing
end