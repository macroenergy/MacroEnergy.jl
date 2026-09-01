Base.@kwdef mutable struct MinCapacityConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64},Dict{Symbol,Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint,Dict{Symbol,Any}} = missing
    # System-wide / per-location configuration: asset-type key => Dict(:edge => fieldname, :value => floor).
    # Populated at load time from the `constraints` block in system_data.json / locations.json.
    config::Union{Missing,Dict{Symbol,Any}} = missing
end

# Store inline configuration parsed from a `constraints` block; see the generic
# `configure_constraint!` fallback in constraints_utils.jl.
configure_constraint!(ct::MinCapacityConstraint, cfg) = (ct.config = cfg; nothing)

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

# Parameter scaling hook (see scaling.jl): the floor `value`s are extensive (capacity) quantities, so
# they are scaled by the same factor as capacity inputs (1/S on scale!, S on unscale!).
function _scale_constraint_config!(ct::MinCapacityConstraint, factor::Float64, visited::Set{UInt64})
    (ismissing(ct.config) || objectid(ct) in visited) && return nothing
    push!(visited, objectid(ct))
    for spec in values(ct.config)
        if haskey(spec, :value) && spec[:value] isa Real
            spec[:value] = spec[:value] * factor
        end
    end
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
    build_grouped_capacity_constraints!(ct, system, model; var=capacity, sense=:geq, name="MinCapacityConstraint")
    return nothing
end

@doc raw"""
    add_model_constraint!(ct::MinCapacityConstraint, location::Location, model::Model)

Add a per-location min capacity constraint: same as the system-wide form, but only assets whose capped
edge is located in `location` contribute. Configuration is carried on `ct.config` (populated from the
`constraints` block of this location in `locations.json`).
"""
function add_model_constraint!(ct::MinCapacityConstraint, location::Location, model::Model)
    build_grouped_capacity_constraints!(ct, location.system, model; var=capacity, sense=:geq, name="MinCapacityConstraint", loc=location.id)
    return nothing
end
