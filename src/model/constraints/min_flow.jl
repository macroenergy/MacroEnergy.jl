Base.@kwdef mutable struct MinFlowConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::MinFlowConstraint, e::Edge, model::Model)
    if e.unidirectional
        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            flow(e, t) >= min_flow_fraction(e) * capacity(e)
        )
    else
        warning("Min flow constraints are available only for unidirectional edges")
    end

    return nothing
end

function add_model_constraint!(ct::MinFlowConstraint, e::EdgeWithUC, model::Model)
    if e.unidirectional
        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            flow(e, t) >= min_flow_fraction(e) * capacity_size(e) * ucommit(e, t)
        )
    else
        warning("Min flow constraints are available only for unidirectional edges")
    end

    return nothing
end
