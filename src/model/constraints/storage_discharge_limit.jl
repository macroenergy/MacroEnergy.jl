
Base.@kwdef mutable struct StorageDischargeLimitConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::StorageDischargeLimitConstraint, e::Edge, model::Model)

    if isa(start_vertex(e), Storage)
        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            balance_data(e, start_vertex(e), :storage) * flow(e, t) <=
            storage_level(start_vertex(e), timestepbefore(t, 1, subperiods(e)))
        )
    end

    return nothing
end
