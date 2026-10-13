"""
    MaxCapacityConstraintConfig(groups)

Typed payload for a system-wide or location-level `MaxCapacityConstraint`. `groups` contains
[`GroupConfig`](@ref) entries whose `value` is an upper bound on the sum of total capacity over the
selected assets.
"""
struct MaxCapacityConstraintConfig <: AbstractGroupedConstraintConfig
    groups::Vector{GroupConfig}
end

Base.@kwdef mutable struct MaxCapacityConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64},Dict{Symbol,Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint,Dict{Symbol,Any}} = missing
    # System-wide / per-location payload, parsed from the `constraints` block at load time.
    config::Union{Missing,MaxCapacityConstraintConfig} = missing
end

requires_constraint_config(::MaxCapacityConstraint) = true
required_constraint_config_type(::MaxCapacityConstraint) = MaxCapacityConstraintConfig
constraint_config_is_missing(ct::MaxCapacityConstraint) = ismissing(ct.config)

function configure_constraint!(ct::MaxCapacityConstraint, raw::AbstractDict)
    ct.config = parse_grouped_constraint_config(
        raw,
        MaxCapacityConstraintConfig,
        "MaxCapacityConstraint",
    )
    return nothing
end


@doc raw"""
    add_model_constraint!(ct::MaxCapacityConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)

Add a max capacity constraint to the edge or storage `y`. The functional form of the constraint is:

```math
\begin{aligned}
    \text{capacity(y)} \leq \text{max\_capacity(y)}
\end{aligned}
```
"""
function add_model_constraint!(ct::MaxCapacityConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)

    ct.constraint_ref = @constraint(model, capacity(y) <= max_capacity(y))

    return nothing

end

function _scale_constraint_config!(ct::MaxCapacityConstraint, factor::Float64, visited::Set{UInt64})
    (ismissing(ct.config) || objectid(ct) in visited) && return nothing
    push!(visited, objectid(ct))
    ct.config = scale_grouped_constraint_config(ct.config, factor)
    return nothing
end

# Max-capacity grouping: sum each capped edge's total capacity and cap it from above.
function build_max_capacity_constraints!(ct::MaxCapacityConstraint, system::System, model::Model; loc::Union{Missing,Symbol}=missing)
    ismissing(ct.config) && error("MaxCapacityConstraint has no configuration; it must be enabled with a config object in the `constraints` block")
    ct.constraint_ref = build_grouped_capacity_constraints(
        ct.config,
        system,
        model;
        variable=capacity,
        sense=:leq,
        constraint_name="MaxCapacityConstraint",
        location=loc,
    )
    return nothing
end

@doc raw"""
    add_model_constraint!(ct::MaxCapacityConstraint, system::System, model::Model)

Add a system-wide max capacity constraint capping, for each configured asset type, the total capacity
of a named edge across all assets of that type. Configuration is carried on `ct.config` (populated from
the `constraints` block in `system_data.json`). The functional form is:

```math
\begin{aligned}
    \sum_{a \in \mathcal{A}}\text{capacity}(a.\text{edge}) \leq \text{value}(\mathcal{A})
\end{aligned}
```
"""
function add_model_constraint!(ct::MaxCapacityConstraint, system::System, model::Model)
    build_max_capacity_constraints!(ct, system, model)
    return nothing
end

@doc raw"""
    add_model_constraint!(ct::MaxCapacityConstraint, location::Location, model::Model)

Add a per-location max capacity constraint: same as the system-wide form, but only assets whose capped
edge is located in `location` contribute. Configuration is carried on `ct.config` (populated from the
`constraints` block of this location in `locations.json`).
"""
function add_model_constraint!(ct::MaxCapacityConstraint, location::Location, model::Model)
    build_max_capacity_constraints!(ct, location.system, model; loc=location.id)
    return nothing
end
