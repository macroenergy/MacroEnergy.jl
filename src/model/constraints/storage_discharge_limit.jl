
Base.@kwdef mutable struct StorageDischargeLimitConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::StorageDischargeLimitConstraint, e::AbstractEdge, model::Model)

Add a storage discharge limit constraint to the edge `e` if the start vertex of the edge is a storage. The functional form of the constraint is:

```math
\begin{aligned}
   \frac{\text{flow(e, t)}}{\text{efficiency(e)}} \leq \text{storage\_level(start\_vertex(e), timestepbefore(t, 1, subperiods(e)))}
\end{aligned}
```
for each time `t` in `time_interval(e)` for the edge `e`. The function [`timestepbefore`](@ref) is used to perform the time wrapping within the subperiods and get the correct time step before `t`.

!!! note "Storage discharge limit constraint"
    This constraint is only applied to edges with a start vertex that is a storage.

!!! note "Storage discharge limit constraint"
    This constraint is only valid for unidirectional edges with or without unit commitment.
"""
function add_model_constraint!(ct::StorageDischargeLimitConstraint, e::AbstractEdge, model::Model)

    if isa(start_vertex(e), Storage)
        storage_data = balance_data(start_vertex(e), :storage)
        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            balance_term_coefficient(storage_data, e, start_vertex(e), t) * flow(e, t) <=
            storage_level(start_vertex(e), timestepbefore(t, 1, subperiods(e)))
        )
    end

    return nothing
end

function add_model_constraint!(ct::StorageDischargeLimitConstraint, e::BidirectionalEdge, model::Model)
    @warn "Storage discharge limit constraint is not applicable to bidirectional edges. No constraint added."
    return nothing
end
