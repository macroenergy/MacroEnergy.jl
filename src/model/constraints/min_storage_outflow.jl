Base.@kwdef mutable struct MinStorageOutflowConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::MinStorageOutflowConstraint, g::Storage, model::Model)
    discharge_edge = g.discharge_edge;
    spillage_edge = g.spillage_edge;
    
    if !isnothing(spillage_edge)

        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(g)],
            flow(spillage_edge, t) + flow(discharge_edge,t) >= min_outflow_fraction(g) * capacity(discharge_edge)
        )
        
    else
        @warn "Min outflow constraints for $(g.id) are not being created because it does not have a spillage edge. 
        If the discharge edge is the only outflow, you should apply MinFlowConstraint to the discharge edge."
    end

    return nothing
end