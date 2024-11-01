Base.@kwdef mutable struct MinCapacityConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end


function add_model_constraint!(ct::MinCapacityConstraint, e::Edge, model::Model)

    ct.constraint_ref = @constraint(model, capacity(e) >= min_capacity(e))

    return nothing

end

function add_model_constraint!(ct::MinCapacityConstraint, g::Storage, model::Model)

    ct.constraint_ref = @constraint(model, capacity_storage(g) >= min_capacity_storage(e))

    return nothing

end
