Base.@kwdef mutable struct MinUpTimeConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

Base.@kwdef mutable struct MinDownTimeConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::MinDownTimeConstraint, e::EdgeWithUC, model::Model)

Add a min down time constraint to the edge `e` with unit commitment. The functional form of the constraint is:

```math
\begin{aligned}
    \frac{\text{capacity(e)}}{\text{capacity\_size(e)}} - \text{ucommit(e, t)} \geq \sum_{h=0}^{\text{min\_down\_time(e)}-1} \text{ushut(e, t-h)}
\end{aligned}
```
for each time `t` in `time_interval(e)` for the edge `e`. The function [`timestepbefore`](@ref) is used to perform the time wrapping within the subperiods and get the correct time step before `t`.

!!! note "Min down time duration"
    This constraint will throw an error if the minimum down time is longer than the length of one subperiod.
"""
function add_model_constraint!(ct::MinDownTimeConstraint, e::EdgeWithUC, model::Model)

    if min_down_time(e) > minimum(length.(subperiods(e)))
        error(
            "The minimum down time for $(id(e)) is longer than the length of one subperiod",
        )
    else

        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            capacity(e) / capacity_size(e) - ucommit(e, t) >= sum(
                ushut(e, s) for
                s in [timestepbefore(t, h, subperiods(e)) for h = 0:min_down_time(e)-1];
                init = 0,
            )
        )
    end

    return nothing
end

@doc raw"""
    add_model_constraint!(ct::MinUpTimeConstraint, e::EdgeWithUC, model::Model)

Add a min up time constraint to the edge `e` with unit commitment. The functional form of the constraint is:

```math
\begin{aligned}
    \text{ucommit(e, t)} \geq \sum_{h=0}^{\text{min\_up\_time(e)}-1} \text{ustart(e, t-h)}
\end{aligned}
```
for each time `t` in `time_interval(e)` for the edge `e`. The function [`timestepbefore`](@ref) is used to perform the time wrapping within the subperiods and get the correct time step before `t`.

!!! note "Min up time duration"
    This constraint will throw an error if the minimum up time is longer than the length of one subperiod.
"""
function add_model_constraint!(ct::MinUpTimeConstraint, e::EdgeWithUC, model::Model)
    if min_up_time(e) > minimum(length.(subperiods(e)))
        error("The minimum up time for $(id(e)) is longer than the length of one subperiod")
    else
        ct.constraint_ref = @constraint(
            model,
            [t in time_interval(e)],
            ucommit(e, t) >= sum(
                ustart(e, s) for
                s in [timestepbefore(t, h, subperiods(e)) for h = 0:min_up_time(e)-1];
                init = 0,
            )
        )
    end

    return nothing
end
