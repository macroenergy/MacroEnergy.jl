"""
    MinCapacityConstraintConfig(groups)

Typed payload for a system-wide or location-level `MinCapacityConstraint`. `groups` contains
[`GroupConfig`](@ref) entries whose `value` is a lower bound on the sum of total capacity over the
selected assets.
"""
struct MinCapacityConstraintConfig <: AbstractGroupedConstraintConfig
    groups::Vector{GroupConfig}
end

Base.@kwdef mutable struct MinCapacityConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64},Dict{Symbol,Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint,Dict{Symbol,Any}} = missing
    # System-wide / per-location payload, parsed from the `constraints` block at load time.
    config::Union{Missing,MinCapacityConstraintConfig} = missing
end

requires_constraint_config(::MinCapacityConstraint) = true
required_constraint_config_type(::MinCapacityConstraint) = MinCapacityConstraintConfig
constraint_config_is_missing(ct::MinCapacityConstraint) = ismissing(ct.config)

function configure_constraint!(ct::MinCapacityConstraint, raw::AbstractDict)
    ct.config = parse_grouped_constraint_config(
        raw,
        MinCapacityConstraintConfig,
        "MinCapacityConstraint",
    )
    return nothing
end

@doc raw"""
    add_model_constraint!(ct::MinCapacityConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)

Add a min capacity constraint to the edge or storage `y`. The functional form of the constraint is:

```math
\begin{aligned}
    \text{capacity(y)} \geq \text{min\_capacity(y)}
\end{aligned}
```
"""
function add_model_constraint!(ct::MinCapacityConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)

    ct.constraint_ref = @constraint(model, capacity(y) >= min_capacity(y))

    return nothing
end

function _scale_constraint_config!(ct::MinCapacityConstraint, factor::Float64, visited::Set{UInt64})
    (ismissing(ct.config) || objectid(ct) in visited) && return nothing
    push!(visited, objectid(ct))
    ct.config = scale_grouped_constraint_config(ct.config, factor)
    return nothing
end

@doc raw"""
    add_model_constraint!(ct::MinCapacityConstraint, system::System, model::Model)

Add a system-wide min capacity constraint requiring, for each configured asset type, the total capacity
of a named edge across all assets of that type to be at least `value`. Configuration is carried on
`ct.config` (populated from the `constraints` block in `system_data.json`). The functional form is:

```math
\begin{aligned}
    \sum_{a \in \mathcal{A}}\text{capacity}(a.\text{edge}) \geq \text{value}(\mathcal{A})
\end{aligned}
```
"""
function add_model_constraint!(ct::MinCapacityConstraint, system::System, model::Model)
    ismissing(ct.config) && error("MinCapacityConstraint has no configuration; it must be enabled with a config object in the `constraints` block")
    ct.constraint_ref = build_grouped_capacity_constraints(
        ct.config,
        system,
        model;
        variable=capacity,
        sense=:geq,
        constraint_name="MinCapacityConstraint",
    )
    return nothing
end

@doc raw"""
    add_model_constraint!(ct::MinCapacityConstraint, location::Location, model::Model)

Add a per-location min capacity constraint: same as the system-wide form, but only assets whose capped
edge is located in `location` contribute. Configuration is carried on `ct.config` (populated from the
`constraints` block of this location in `locations.json`).
"""
function add_model_constraint!(ct::MinCapacityConstraint, location::Location, model::Model)
    ismissing(ct.config) && error("MinCapacityConstraint has no configuration; it must be enabled with a config object in the `constraints` block")
    ct.constraint_ref = build_grouped_capacity_constraints(
        ct.config,
        location.system,
        model;
        variable=capacity,
        sense=:geq,
        constraint_name="MinCapacityConstraint",
        location=location.id,
    )
    return nothing
end
