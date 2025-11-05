Base.@kwdef mutable struct RampingLimitConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::RampingLimitConstraint, e::Edge, model::Model)

Add a ramping limit constraint to the edge `e`. The functional form of the ramping up limit constraint is:

```math
\begin{aligned}
    \text{flow(e, t)} - \text{flow(e, t-1)} + \text{regulation\_term(e, t)} + \text{reserves\_term(e, t)} - \text{ramp\_up\_fraction(e)} \times \text{capacity(e)} \leq 0
\end{aligned}
```
On the other hand, the ramping down limit constraint is:

```math
\begin{aligned}
    \text{flow(e, t-1)} - \text{flow(e, t)} + \text{regulation\_term(e, t)} + \text{reserves\_term(e, t)} - \text{ramp\_down\_fraction(e)} \times \text{capacity(e)} \leq 0
\end{aligned}
```
for each time `t` in `time_interval(e)` for the edge `e`. The function [`timestepbefore`](@ref) is used to perform the time wrapping within the subperiods and get the correct time step before `t`.
"""
function add_model_constraint!(ct::RampingLimitConstraint, e::Edge, model::Model)

    #### For now these are set to zero because we are not modeling reserves
    reserves_term = @expression(model, [t in time_interval(e)], 0 * model[:vREF])
    regulation_term = @expression(model, [t in time_interval(e)], 0 * model[:vREF])

    eRampUp = @expression(
        model,
        [t in time_interval(e)],
        flow(e, t) - flow(e, timestepbefore(t, 1, subperiods(e))) +
        regulation_term[t] +
        reserves_term[t] - ramp_up_fraction(e) * capacity(e)
    )

    eRampDown = @expression(
        model,
        [t in time_interval(e)],
        flow(e, timestepbefore(t, 1, subperiods(e))) - flow(e, t) - regulation_term[t] +
        reserves_term[timestepbefore(t, 1, subperiods(e))] -
        ramp_down_fraction(e) * capacity(e)
    )

    ramp_expr_dict = Dict(:RampUp => eRampUp, :RampDown => eRampDown)

    ct.constraint_ref = @constraint(
        model,
        [s in [:RampUp, :RampDown], t in time_interval(e)],
        ramp_expr_dict[s][t] <= 0
    )

    return nothing
end

@doc raw"""
    add_model_constraint!(ct::RampingLimitConstraint, e::EdgeWithUC, model::Model)

Add a ramping limit constraint to the edge `e` with unit commitment. The functional form of the ramping up limit constraint is:

```math
\begin{aligned}
    \text{flow(e, t)} - \text{flow(e, t-1)} + \text{regulation\_term(e, t)} + \text{reserves\_term(e, t)} - \text{ramp\_up\_fraction(e)} \times \text{capacity\_size(e)} \times (\text{ucommit(e, t)} - \text{ustart(e, t)}) + \text{min(availability(e, t), max(min\_flow\_fraction(e), ramp\_up\_fraction(e)))} \times \text{capacity\_size(e)} \times \text{ustart(e, t)} - \text{min\_flow\_fraction(e)} \times \text{capacity\_size(e)} \times \text{ushut(e, t)} \leq 0
\end{aligned}
```

On the other hand, the ramping down limit constraint is:

```math
\begin{aligned}
    \text{flow(e, t-1)} - \text{flow(e, t)} + \text{regulation\_term(e, t)} + \text{reserves\_term(e, t)} - \text{ramp\_down\_fraction(e)} \times \text{capacity\_size(e)} \times (\text{ucommit(e, t)} - \text{ustart(e, t)}) - \text{min\_flow\_fraction(e)} \times \text{capacity\_size(e)} \times \text{ustart(e, t)} + \text{min(availability(e, t), max(min\_flow\_fraction(e), ramp\_down\_fraction(e)))} \times \text{capacity\_size(e)} \times \text{ushut(e, t)} \leq 0
\end{aligned}
```

for each time `t` in `time_interval(e)` for the edge `e`. The function [`timestepbefore`](@ref) is used to perform the time wrapping within the subperiods and get the correct time step before `t`.
"""
function add_model_constraint!(ct::RampingLimitConstraint, e::EdgeWithUC, model::Model)

    #### For now these are set to zero because we are not modeling reserves
    reserves_term = @expression(model, [t in time_interval(e)], 0 * model[:vREF])
    regulation_term = @expression(model, [t in time_interval(e)], 0 * model[:vREF])

    eRampUp = @expression(
        model,
        [t in time_interval(e)],
        flow(e, t) - flow(e, timestepbefore(t, 1, subperiods(e))) +
        regulation_term[t] +
        reserves_term[t] - (
            ramp_up_fraction(e) * capacity_size(e) * (ucommit(e, t) - ustart(e, t)) +
            min(availability(e, t), max(min_flow_fraction(e), ramp_up_fraction(e))) *
            capacity_size(e) *
            ustart(e, t) - min_flow_fraction(e) * capacity_size(e) * ushut(e, t)
        )
    )

    eRampDown = @expression(
        model,
        [t in time_interval(e)],
        flow(e, timestepbefore(t, 1, subperiods(e))) - flow(e, t) - regulation_term[t] +
        reserves_term[timestepbefore(t, 1, subperiods(e))] - (
            ramp_down_fraction(e) * capacity_size(e) * (ucommit(e, t) - ustart(e, t)) -
            min_flow_fraction(e) * capacity_size(e) * ustart(e, t) +
            min(availability(e, t), max(min_flow_fraction(e), ramp_down_fraction(e))) *
            capacity_size(e) *
            ushut(e, t)
        )
    )

    ramp_expr_dict = Dict(:RampUp => eRampUp, :RampDown => eRampDown)

    ct.constraint_ref = @constraint(
        model,
        [s in [:RampUp, :RampDown], t in time_interval(e)],
        ramp_expr_dict[s][t] <= 0
    )
    return nothing
end
