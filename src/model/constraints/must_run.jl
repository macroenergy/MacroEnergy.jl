Base.@kwdef mutable struct MustRunConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::MustRunConstraint, e::Edge, model::Model)
    if e.unidirectional

        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            flow(e, t) == availability(e, t) * capacity(e)
        )
    else
         @warn "MustRunConstraint required for an edge that is not unidirectional so MACRO will not create this constraint"
    end

    return nothing
end