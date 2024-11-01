Base.@kwdef mutable struct MaxCapacityConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end


function add_model_constraint!(ct::MaxCapacityConstraint, e::Edge, model::Model)

    ct.constraint_ref = @constraint(model, capacity(e) <= max_capacity(e))

    return nothing

end

function add_model_constraint!(ct::MaxCapacityConstraint, g::Storage, model::Model)

    ct.constraint_ref = @constraint(model, capacity_storage(g) <= max_capacity_storage(g))

    return nothing

end
