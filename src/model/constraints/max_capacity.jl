Base.@kwdef mutable struct MaxCapacityConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64},Dict{Symbol,Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint,Dict{Symbol,Any}} = missing
    # System-wide / per-location configuration: asset-type key => Dict(:edge => fieldname, :value => cap).
    # Populated at load time from the `constraints` block in system_data.json / locations.json.
    config::Union{Missing,Dict{Symbol,Any}} = missing
end

# Store inline configuration parsed from a `constraints` block; see the generic
# `configure_constraint!` fallback in constraints_utils.jl.
configure_constraint!(ct::MaxCapacityConstraint, cfg) = (ct.config = cfg; nothing)


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

"""
    resolve_assets_by_type_key(system::System, key::Symbol)

Resolve a `MaxCapacityConstraint` settings key to the matching assets in `system`.

Prefers Julia subtyping: if `key` names a defined asset type — a concrete type (`:Battery`), or a
parametric base whose `UnionAll` matches every variant (`:VRE` matches `VRE{:Solar}`, `VRE{:Wind}`,
…; `:ThermalPower` matches every commodity variant) — assets are matched with `isa`. Otherwise it
falls back to string matching via [`search_assets`](@ref), which handles exact parametric instances
(`Symbol("VRE{Solar}")`, `Symbol("ThermalPower{NaturalGas}")`) and wildcards (`Symbol("VRE*")`).
"""
function resolve_assets_by_type_key(system::System, key::Symbol)
    # Fast path: the key names an asset type (concrete, or a parametric/abstract base). Match by `isa`
    # in a single pass, with no per-asset string work.
    if isdefined(MacroEnergy, key)
        T = getfield(MacroEnergy, key)
        if isa(T, Type) && T <: AbstractAsset
            return filter(a -> isa(a, T), system.assets)
        end
    end
    # Fallback (exact parametric instance / wildcard): compute each asset's type string once, then
    # match via a Set for O(1) membership instead of a repeated linear `in` over a Vector.
    type_strings = get_type.(system.assets)
    matched = Set(first(search_assets(string(key), unique(type_strings))))
    return [a for (a, ts) in zip(system.assets, type_strings) if ts in matched]
end

# Location of the capacity associated with edge `e`: the edge's own location if set, otherwise the
# location of a connected vertex, preferring the end vertex (the bus a generation asset injects into)
# over the start vertex (typically the asset's transformation).
function capped_edge_location(e::AbstractEdge)
    ismissing(e.location) || return e.location
    for v in (end_vertex(e), start_vertex(e))
        ismissing(location(v)) || return location(v)
    end
    return missing
end

# Parameter scaling hook (see scaling.jl): the cap `value`s are extensive (capacity) quantities, so
# they are scaled by the same factor as capacity inputs (1/S on scale!, S on unscale!).
function _scale_constraint_config!(ct::MaxCapacityConstraint, factor::Float64, visited::Set{UInt64})
    (ismissing(ct.config) || objectid(ct) in visited) && return nothing
    push!(visited, objectid(ct))
    for spec in values(ct.config)
        if haskey(spec, :value) && spec[:value] isa Real
            spec[:value] = spec[:value] * factor
        end
    end
    return nothing
end

# Build one grouped-capacity constraint per asset-type key in `ct.config`, storing them in
# `ct.constraint_ref` keyed by asset type. Shared by the system-wide / per-location capacity-group
# constraints (max capacity, min capacity, max new capacity); they differ only in `var` (the capacity
# variable summed over each capped edge) and `sense` (`:leq` for upper bounds, `:geq` for lower bounds).
# When `loc` is given, only assets whose capped edge sits in that location contribute (per-location
# scope); otherwise all matched assets contribute (system scope).
function build_grouped_capacity_constraints!(ct, system::System, model::Model;
        var::Function, sense::Symbol, name::String, loc::Union{Missing,Symbol}=missing)
    ismissing(ct.config) && error("$name has no configuration; it must be enabled with a config object in the `constraints` block")

    ct.constraint_ref = Dict{Symbol,Any}()
    for (at, spec) in ct.config
        constraint_assets = resolve_assets_by_type_key(system, at)
        # If the asset type is not recognized anywhere in the system, skip it entirely (no constraint).
        if isempty(constraint_assets)
            @warn "$name: asset type `$at` matched no assets in the system; skipping"
            continue
        end
        edge_field = Symbol(spec[:edge])
        total_capacity = AffExpr(0.0)
        contributed = false
        for a in constraint_assets
            edge_field in fieldnames(typeof(a)) || error("$name: asset type $at (`$(get_type(a))`) has no edge field `$edge_field`")
            e = get_component_by_fieldname(a, edge_field)
            if !has_capacity(e)
                @warn "$name: edge field `$edge_field` of asset $(id(a)) (`$(get_type(a))`) has no capacity variable; skipping"
                continue
            end
            # Per-location scope: skip assets not located in `loc`.
            ismissing(loc) || capped_edge_location(e) == loc || continue
            add_to_expression!(total_capacity, var(e))
            contributed = true
        end
        # Skip empty groups (e.g. a location with no assets of this type): no constraint needed.
        contributed || continue
        ct.constraint_ref[at] = sense === :leq ?
            @constraint(model, total_capacity <= spec[:value]) :
            @constraint(model, total_capacity >= spec[:value])
    end
    return nothing
end

# Max-capacity grouping: sum each capped edge's total capacity and cap it from above.
function build_max_capacity_constraints!(ct::MaxCapacityConstraint, system::System, model::Model; loc::Union{Missing,Symbol}=missing)
    build_grouped_capacity_constraints!(ct, system, model; var=capacity, sense=:leq, name="MaxCapacityConstraint", loc=loc)
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
