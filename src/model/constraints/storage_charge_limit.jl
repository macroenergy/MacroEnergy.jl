Base.@kwdef mutable struct StorageChargeLimitConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::StorageChargeLimitConstraint, e::AbstractEdge, model::Model)

Add a storage charge limit constraint to the edge `e` if the end vertex of the edge is a storage. The functional form of the constraint is:

```math
\begin{aligned}
   \text{efficiency(e)}\text{flow(e, t)} \leq \text{capacity(end\_vertex(e))} - \text{storage\_level(end\_vertex(e), timestepbefore(t, 1, subperiods(e)))}
\end{aligned}
```
for each time `t` in `time_interval(e)` for the edge `e`. The function [`timestepbefore`](@ref) is used to perform the time wrapping within the subperiods and get the correct time step before `t`.

!!! note "Storage charge limit constraint"
    This constraint is only applied to edges with an end vertex that is a storage.

!!! note "Storage charge limit constraint"
    This constraint is only valid for unidirectional edges with or without unit commitment.
"""
function add_model_constraint!(ct::StorageChargeLimitConstraint, e::AbstractEdge, model::Model)

    if isa(end_vertex(e), Storage)
        storage_data = balance_data(end_vertex(e), :storage)
        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            balance_term_coefficient(storage_data, e, end_vertex(e), t) * flow(e, t) <=
            capacity(end_vertex(e)) - storage_level(end_vertex(e), timestepbefore(t, 1, subperiods(e)))
        )
    end

    return nothing
end

function add_model_constraint!(ct::StorageChargeLimitConstraint, e::BidirectionalEdge, model::Model)
    @warn "Storage charge limit constraint is not applicable to bidirectional edges. No constraint added."
    return nothing
end
