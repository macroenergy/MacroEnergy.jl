Base.@kwdef mutable struct FlexDemandConstraint <: OperationConstraint
    efficiency::Float64 = 1.0
    max_delay::Int = 0
    max_advance::Int = 0
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Dict{Symbol,Vector{Float64}}} = missing
    constraint_ref::Union{Missing,Dict{Symbol,Any}} = missing
end

@doc raw"""
    add_model_constraint!(ct::FlexDemandConstraint, g::Storage, model::Model)

Adds the rate limit and the delay and advance windows of a [Flexible Demand](@ref) asset, as in GenX's flexible
demand. The storage level ``\Gamma`` is the deferred demand, the charge edge of `g` carries the deferred demand
``\Pi`` and the discharge edge the served demand ``\Theta``:

```math
\begin{aligned}
    \eta \, \Theta(t) &\leq \Delta \\
    \sum_{k=1}^{\tau_d} \Theta(t+k) &\geq \Gamma(t) \\
    \sum_{k=1}^{\tau_a} \Pi(t+k) &\geq -\Gamma(t)
\end{aligned}
```

for each time `t` in the time interval of `g`, where ``\Delta`` is the capacity of the charge edge, ``\eta`` is
`ct.efficiency`, ``\tau_d`` is `ct.max_delay` and ``\tau_a`` is `ct.max_advance`, in time steps. `t + k` wraps
within the subperiod, as [`timestepbefore`](@ref) with a negative lag.
"""
function add_model_constraint!(ct::FlexDemandConstraint, g::Storage, model::Model)
    defer = charge_edge(g)
    serve = discharge_edge(g)
    ti = time_interval(g)
    sps = subperiods(g)
    cap = capacity(defer)
    efficiency = ct.efficiency
    max_delay = ct.max_delay
    max_advance = ct.max_advance
    ct.constraint_ref = Dict{Symbol,Any}(
        :serve_limit => @constraint(
            model,
            [t in ti],
            container = array_container(ti),
            efficiency * flow(serve, t) <= cap
        ),
        :delay => @constraint(
            model,
            [t in ti],
            container = array_container(ti),
            sum(flow(serve, timestepbefore(t, -k, sps)) for k in 1:max_delay; init = 0) >= storage_level(g, t)
        ),
        :advance => @constraint(
            model,
            [t in ti],
            container = array_container(ti),
            sum(flow(defer, timestepbefore(t, -k, sps)) for k in 1:max_advance; init = 0) >= -storage_level(g, t)
        ),
    )
    return nothing
end
