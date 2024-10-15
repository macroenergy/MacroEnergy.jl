Base.@kwdef mutable struct HydroMinFlowConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::HydroMinFlowConstraint, e::Edge, model::Model)
    if e.unidirectional
        #### Edge "e" is a spill edge, we need to get the discharge edge as well:
        hydrostor = start_vertex(e);
        discharge_edge = hydrostor.discharge_edge;

        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            flow(e, t) + flow(discharge_edge) >= min_flow_fraction(e) * capacity(discharge_edge)
        )
    else
        warning("Min Hydro flow constraints are available only for unidirectional spill edges")
    end

    return nothing
end