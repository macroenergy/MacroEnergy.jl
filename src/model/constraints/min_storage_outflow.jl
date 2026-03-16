Base.@kwdef mutable struct MinStorageOutflowConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::MinStorageOutflowConstraint, g::AbstractStorage, model::Model)

Add a min storage outflow constraint to the storage `g` part of a `HydroRes` asset. The functional form of the constraint is:

```math
\begin{aligned}
    \text{flow(spillage\_edge, t)} + \text{flow(discharge\_edge, t)} \geq \text{min\_outflow\_fraction(g)} \times \text{capacity(discharge\_edge)}
\end{aligned}
```
for each time `t` in `time_interval(g)` for the storage `g`.

!!! warning "Only applies to HydroRes assets"
    This constraint only applies to HydroRes assets. It returns a warning if the storage `g` does not have a spillage edge. 
    If the discharge edge is the only outflow, you should apply MinFlowConstraint to the discharge edge.
"""
function add_model_constraint!(ct::MinStorageOutflowConstraint, g::AbstractStorage, model::Model)
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