"""
    MaxNewCapacityConstraintConfig(groups)

Typed payload for a system-wide or location-level `MaxNewCapacityConstraint`. `groups` contains
[`GroupConfig`](@ref) entries whose `value` is an upper bound on the sum of newly built capacity
over the selected assets.
"""
struct MaxNewCapacityConstraintConfig <: AbstractGroupedConstraintConfig
    groups::Vector{GroupConfig}
end

Base.@kwdef mutable struct MaxNewCapacityConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64},Dict{Symbol,Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint,Dict{Symbol,Any}} = missing
    # System-wide / per-location payload, parsed from the `constraints` block at load time.
    config::Union{Missing,MaxNewCapacityConstraintConfig} = missing
end

requires_constraint_config(::MaxNewCapacityConstraint) = true
required_constraint_config_type(::MaxNewCapacityConstraint) = MaxNewCapacityConstraintConfig
constraint_config_is_missing(ct::MaxNewCapacityConstraint) = ismissing(ct.config)

function configure_constraint!(ct::MaxNewCapacityConstraint, raw::AbstractDict)
    ct.config = parse_grouped_constraint_config(
        raw,
        MaxNewCapacityConstraintConfig,
        "MaxNewCapacityConstraint",
    )
    return nothing
end

@doc raw"""
    add_model_constraint!(ct::MaxNewCapacityConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)

Add a max new capacity constraint to the edge or storage `y`. The functional form of the constraint is:

```math
\begin{aligned}
    \text{new\_capacity(y)} \leq \text{max\_new\_capacity(y)}
\end{aligned}
```
"""
function add_model_constraint!(ct::MaxNewCapacityConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)

    ct.constraint_ref = @constraint(model, new_capacity(y) <= max_new_capacity(y))

    return nothing

end

function _scale_constraint_config!(ct::MaxNewCapacityConstraint, factor::Float64, visited::Set{UInt64})
    (ismissing(ct.config) || objectid(ct) in visited) && return nothing
    push!(visited, objectid(ct))
    ct.config = scale_grouped_constraint_config(ct.config, factor)
    return nothing
end

@doc raw"""
    add_model_constraint!(ct::MaxNewCapacityConstraint, system::System, model::Model)

Add a system-wide max new capacity constraint capping, for each configured asset type, the total newly
built capacity of a named edge across all assets of that type. Configuration is carried on `ct.config`
(populated from the `constraints` block in `system_data.json`). The functional form is:

```math
\begin{aligned}
    \sum_{a \in \mathcal{A}}\text{new\_capacity}(a.\text{edge}) \leq \text{value}(\mathcal{A})
\end{aligned}
```
"""
function add_model_constraint!(ct::MaxNewCapacityConstraint, system::System, model::Model)
    ismissing(ct.config) && error("MaxNewCapacityConstraint has no configuration; it must be enabled with a config object in the `constraints` block")
    ct.constraint_ref = build_grouped_capacity_constraints(
        ct.config,
        system,
        model;
        variable=new_capacity,
        sense=:leq,
        constraint_name="MaxNewCapacityConstraint",
    )
    return nothing
end

@doc raw"""
    add_model_constraint!(ct::MaxNewCapacityConstraint, location::Location, model::Model)

Add a per-location max new capacity constraint: same as the system-wide form, but only assets whose
capped edge is located in `location` contribute. Configuration is carried on `ct.config` (populated from
the `constraints` block of this location in `locations.json`).
"""
function add_model_constraint!(ct::MaxNewCapacityConstraint, location::Location, model::Model)
    ismissing(ct.config) && error("MaxNewCapacityConstraint has no configuration; it must be enabled with a config object in the `constraints` block")
    ct.constraint_ref = build_grouped_capacity_constraints(
        ct.config,
        location.system,
        model;
        variable=new_capacity,
        sense=:leq,
        constraint_name="MaxNewCapacityConstraint",
        location=location.id,
    )
    return nothing
end
