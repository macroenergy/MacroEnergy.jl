@doc raw"""
    add_deployment_inertia!(model::Model, systems::Vector{System}, settings::NamedTuple)

Add deployment inertia ("speed limit") constraints to `model`. They limit how fast
the new capacity added per period of each technology category may grow or decline
from one period to the next. A category groups the edges whose
`Inertia_category` is listed in the case setting `TechsWithInertia`.

In the first period, new capacity of category ``t`` is bounded around its recent
historical deployment ``\text{InertiaInitMW}_t``:

```math
\begin{aligned}
    \sum_{e \in t} \text{new\_capacity}_{e,1} &\leq \text{InertiaInitMW}_t \, (1 + \text{InertiaInitialGrowthRate}_t) \\
    \sum_{e \in t} \text{new\_capacity}_{e,1} &\geq \text{InertiaInitMW}_t \, (1 - \text{InertiaInitialDeclineRate}_t)
\end{aligned}
```

In later periods ``p``, it is bounded by the previous period's new capacity, using each
edge's compound annual growth (`cagr`) and decline (`cadr`) rates, plus an allowance
``\text{InertiaMinMW}_t`` that can always be built (or dropped):

```math
\begin{aligned}
    \sum_{e \in t} \left( \text{new\_capacity}_{e,p} - (1 + \text{cagr}_e)\, \text{new\_capacity}_{e,p-1} \right) &\leq \text{InertiaMinMW}_t \\
    \sum_{e \in t} \left( \text{new\_capacity}_{e,p} - (1 - \text{cadr}_e)\, \text{new\_capacity}_{e,p-1} \right) &\geq -\text{InertiaMinMW}_t
\end{aligned}
```

The MW settings are divided by `ParameterScalingFactor` when `ParameterScaling` is on.
The left-hand sides are registered as `eDeploymentGrowth` / `eDeploymentDecline` and the
constraints as `cDeploymentGrowth` / `cDeploymentDecline`, indexed by `[category, period]`.
"""
function add_deployment_inertia!(model::Model, systems::Vector{System}, settings::NamedTuple)
    get(settings, :DeploymentInertia, false) || return nothing
    techs = string.(collect(settings.TechsWithInertia))
    isempty(techs) && return nothing
    validate_deployment_inertia_settings(techs, settings)

    @info(" -- Adding deployment inertia constraints")
    scaling_factor = settings.ParameterScaling ? Float64(settings.ParameterScalingFactor) : 1.0
    periods = period_index.(systems)

    @expression(model, eDeploymentGrowth[t in techs, p in periods], AffExpr(0.0))
    @expression(model, eDeploymentDecline[t in techs, p in periods], AffExpr(0.0))

    for system in systems, e in get_edges(system)
        category = inertia_category(e)
        (has_capacity(e) && !isnothing(category) && category in techs) || continue
        p = period_index(e)
        add_to_expression!(eDeploymentGrowth[category, p], new_capacity(e))
        add_to_expression!(eDeploymentDecline[category, p], new_capacity(e))
        if p > 1
            # Previous period's new capacity: a model expression when periods are solved
            # together, a fixed value when they are solved one at a time (myopic)
            prev = new_capacity_track(e, p - 1)
            add_to_expression!(eDeploymentGrowth[category, p], -(1 + cagr(e)) * prev)
            add_to_expression!(eDeploymentDecline[category, p], -(1 - cadr(e)) * prev)
        end
    end

    growth_limit(t, p) = p == 1 ?
        settings.InertiaInitMW[Symbol(t)] * (1 + settings.InertiaInitialGrowthRate[Symbol(t)]) / scaling_factor :
        settings.InertiaMinMW[Symbol(t)] / scaling_factor
    decline_limit(t, p) = p == 1 ?
        settings.InertiaInitMW[Symbol(t)] * (1 - settings.InertiaInitialDeclineRate[Symbol(t)]) / scaling_factor :
        -settings.InertiaMinMW[Symbol(t)] / scaling_factor

    @constraint(model, cDeploymentGrowth[t in techs, p in periods], eDeploymentGrowth[t, p] <= growth_limit(t, p))
    @constraint(model, cDeploymentDecline[t in techs, p in periods], eDeploymentDecline[t, p] >= decline_limit(t, p))

    return nothing
end

function validate_deployment_inertia_settings(techs::Vector{String}, settings::NamedTuple)
    for key in (:InertiaInitMW, :InertiaInitialGrowthRate, :InertiaInitialDeclineRate, :InertiaMinMW)
        missing_techs = [t for t in techs if !haskey(settings[key], Symbol(t))]
        isempty(missing_techs) || error("DeploymentInertia: case setting $key has no value for $(join(missing_techs, ", ")) (listed in TechsWithInertia)")
    end
    return nothing
end
