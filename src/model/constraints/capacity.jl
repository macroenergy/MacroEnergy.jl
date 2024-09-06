Base.@kwdef mutable struct CapacityConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end


function add_model_constraint!(ct::CapacityConstraint, e::Edge, model::Model)

    if e.unidirectional

        ct.constraint_ref = @constraint(
                model,
                [t in time_interval(e)],
                flow(e,t) <= availability(e,t)*capacity(e)
            )
    else
        ct.constraint_ref = @constraint(
            model,
            [i in [-1, 1], t in time_interval(e)],
            i * flow(e,t) <= availability(e,t)*capacity(e)
        )
    end

    return nothing

end

function add_model_constraint!(ct::CapacityConstraint, e::EdgeWithUC, model::Model)

    if e.unidirectional

        ct.constraint_ref = @constraint(
                model,
                [t in time_interval(e)],
                flow(e,t) <= availability(e,t)*capacity_size(e)*ucommit(e,t)
            )
    else
        ct.constraint_ref = @constraint(
            model,
            [i in [-1, 1], t in time_interval(e)],
            i * flow(e,t) <= availability(e,t)*capacity_size(e)*ucommit(e,t)
        )
    end
 
    return nothing

end
