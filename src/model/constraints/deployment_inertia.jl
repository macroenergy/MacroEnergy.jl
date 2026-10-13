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

The left-hand sides are registered as `eDeploymentGrowth` / `eDeploymentDecline` and the
constraints as `cDeploymentGrowth` / `cDeploymentDecline`, indexed by `[category, period]`;
the storage energy versions add an `Energy` suffix.
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
        add_inertia_terms!(eDeploymentGrowth, eDeploymentDecline, e, category)
    end

    growth_limit(t, p) = p == 1 ?
        settings.InertiaInitMW[Symbol(t)] * (1 + settings.InertiaInitialGrowthRate[Symbol(t)]) / scaling_factor :
        settings.InertiaMinMW[Symbol(t)] / scaling_factor
    decline_limit(t, p) = p == 1 ?
        settings.InertiaInitMW[Symbol(t)] * (1 - settings.InertiaInitialDeclineRate[Symbol(t)]) / scaling_factor :
        -settings.InertiaMinMW[Symbol(t)] / scaling_factor

    @constraint(model, cDeploymentGrowth[t in techs, p in periods], eDeploymentGrowth[t, p] <= growth_limit(t, p))
    @constraint(model, cDeploymentDecline[t in techs, p in periods], eDeploymentDecline[t, p] >= decline_limit(t, p))

    add_storage_energy_inertia!(model, systems, settings, techs, scaling_factor)

    return nothing
end

"""
    add_storage_energy_inertia!(model, systems, settings, techs, scaling_factor)

Deployment inertia on storage energy capacity (MWh); see `add_deployment_inertia!`.
"""
function add_storage_energy_inertia!(model::Model, systems::Vector{System}, settings::NamedTuple, techs::Vector{String}, scaling_factor::Float64)
    storages = [(g, inertia_category(g)) for system in systems for g in get_storages(system)
                if !isnothing(inertia_category(g)) && inertia_category(g) in techs]
    isempty(storages) && return nothing

    # All storage of a category must share the duration that converts MW settings to MWh
    duration = Dict{String,Float64}()
    for (g, t) in storages
        d = inertia_initial_duration(g)
        get!(duration, t, d) == d || error("DeploymentInertia: all storage in category '$t' must have the same InertiaInitialDuration, found $(duration[t]) and $d")
    end

    periods = period_index.(systems)
    energy_keys = Set((t, period_index(g)) for (g, t) in storages)

    @expression(model, eDeploymentGrowthEnergy[t in techs, p in periods], AffExpr(0.0))
    @expression(model, eDeploymentDeclineEnergy[t in techs, p in periods], AffExpr(0.0))
    for (g, t) in storages
        add_inertia_terms!(eDeploymentGrowthEnergy, eDeploymentDeclineEnergy, g, t)
    end

    growth_limit(t, p) = duration[t] * (p == 1 ?
        settings.InertiaInitMW[Symbol(t)] * (1 + settings.InertiaInitialGrowthRate[Symbol(t)]) :
        settings.InertiaMinMW[Symbol(t)]) / scaling_factor
    decline_limit(t, p) = duration[t] * (p == 1 ?
        settings.InertiaInitMW[Symbol(t)] * (1 - settings.InertiaInitialDeclineRate[Symbol(t)]) :
        -settings.InertiaMinMW[Symbol(t)]) / scaling_factor

    @constraint(model, cDeploymentGrowthEnergy[t in techs, p in periods; (t, p) in energy_keys],
        eDeploymentGrowthEnergy[t, p] <= growth_limit(t, p))
    @constraint(model, cDeploymentDeclineEnergy[t in techs, p in periods; (t, p) in energy_keys],
        eDeploymentDeclineEnergy[t, p] >= decline_limit(t, p))

    return nothing
end

"""
    add_inertia_terms!(growth, decline, y, category)

Add the new capacity of edge or storage `y` to the inertia expressions of `category`, net
of its previous period's new capacity scaled by `1 + cagr` (growth) or `1 - cadr` (decline).
"""
function add_inertia_terms!(growth, decline, y::Union{AbstractEdge,AbstractStorage}, category::String)
    p = period_index(y)
    add_to_expression!(growth[category, p], new_capacity(y))
    add_to_expression!(decline[category, p], new_capacity(y))
    if p > 1
        # Previous period's new capacity: a model expression when periods are solved
        # together, a fixed value when they are solved one at a time (myopic)
        prev = new_capacity_track(y, p - 1)
        add_to_expression!(growth[category, p], -(1 + cagr(y)) * prev)
        add_to_expression!(decline[category, p], -(1 - cadr(y)) * prev)
    end
    return nothing
end

function validate_deployment_inertia_settings(techs::Vector{String}, settings::NamedTuple)
    for key in (:InertiaInitMW, :InertiaInitialGrowthRate, :InertiaInitialDeclineRate, :InertiaMinMW)
        missing_techs = [t for t in techs if !haskey(settings[key], Symbol(t))]
        isempty(missing_techs) || error("DeploymentInertia: case setting $key has no value for $(join(missing_techs, ", ")) (listed in TechsWithInertia)")
    end
    return nothing
end
