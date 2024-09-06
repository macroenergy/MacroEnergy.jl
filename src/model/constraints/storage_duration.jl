Base.@kwdef mutable struct StorageMaxDurationConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(
    ct::StorageMaxDurationConstraint,
    g::Storage,
    model::Model,
)
    e = discharge_edge(g);

    if max_duration(g) > 0
        ct.constraint_ref = @constraint(model, capacity_storage(g) <= max_duration(g) * capacity(e))
    end


    return nothing
end


Base.@kwdef mutable struct StorageMinDurationConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(
    ct::StorageMinDurationConstraint,
    g::Storage,
    model::Model,
)
    e = discharge_edge(g);

    if max_duration(g) > 0
        ct.constraint_ref = @constraint(model, capacity_storage(g) >= min_duration(g) * capacity(e))
    end


    return nothing
end