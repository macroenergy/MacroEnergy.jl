constraint_value(c::AbstractTypeConstraint) = c.constraint_value;
constraint_dual(c::AbstractTypeConstraint) = c.constraint_dual;
constraint_ref(c::AbstractTypeConstraint) = c.constraint_ref;

"""
    configure_constraint!(ct::AbstractTypeConstraint, cfg)

Store inline configuration `cfg` on a constraint instance. `cfg` is the value parsed from a
`constraints` block when it is an object rather than `true` (see `check_and_convert_constraints!`).
Only constraint types that support inline configuration define a method; the generic fallback errors.
"""
configure_constraint!(ct::AbstractTypeConstraint, cfg) =
    error("Constraint $(typeof(ct)) does not support inline configuration")

"""
    AbstractConstraintConfig

Abstract supertype for typed, inline constraint configuration payloads. Constraint types that
support object values in an input `constraints` block define a concrete subtype.
"""
abstract type AbstractConstraintConfig end

"""
    AbstractGroupedConstraintConfig <: AbstractConstraintConfig

Abstract supertype for configurations that define one or more asset groups. Each group selects
assets and constrains a capacity-like quantity on a named edge field.
"""
abstract type AbstractGroupedConstraintConfig <: AbstractConstraintConfig end

"""
    GroupSelector(asset_type, all, any, exclude)

Typed asset selector for a grouped constraint. An asset matches when it matches `asset_type` (when
provided), contains every tag in `all`, contains at least one tag in `any` (when nonempty), and
contains no tag in `exclude`.
"""
struct GroupSelector
    asset_type::Union{Nothing,Symbol}
    all::Vector{Symbol}
    any::Vector{Symbol}
    exclude::Vector{Symbol}
end

GroupSelector(asset_type::Symbol) = GroupSelector(asset_type, Symbol[], Symbol[], Symbol[])

"""
    GroupConfig(name, selector, edge, value)

One asset group in a grouped constraint configuration.

- `name`: unique input key used to identify the group in diagnostics and model references.
- `selector`: typed criteria used to select assets.
- `edge`: field name of the constrained edge on every selected asset.
- `value`: upper or lower bound, depending on the enclosing constraint.
"""
struct GroupConfig
    name::Symbol
    selector::GroupSelector
    edge::Symbol
    value::Float64
end

constraint_groups(config::AbstractGroupedConstraintConfig) = config.groups
group_name(group) = group.name
group_selector(group) = group.selector
group_edge(group) = group.edge
group_value(group) = group.value

requires_constraint_config(::AbstractTypeConstraint) = false
required_constraint_config_type(::AbstractTypeConstraint) = nothing
constraint_config_is_missing(::AbstractTypeConstraint) = false

"""
    validate_required_constraint_configs!(constraints, scope)

Ensure constraints attached at `scope` have the configuration payload required by that scope.
Component-level constraints remain compatible with their legacy Boolean form; grouped constraints
at system and location scope require a typed object payload.
"""
function validate_required_constraint_configs!(
    constraints::AbstractVector{<:AbstractTypeConstraint},
    scope::AbstractString,
)
    for constraint in constraints
        requires_constraint_config(constraint) || continue
        constraint_config_is_missing(constraint) || continue
        config_type = required_constraint_config_type(constraint)
        constraint_name = nameof(typeof(constraint))
        throw(ArgumentError(
            "$constraint_name at $scope requires a $(config_type) configuration object. " *
            "In input JSON, provide an object payload for `$constraint_name` rather than `true`.",
        ))
    end
    return nothing
end

"""
    parse_grouped_constraint_config(raw, config_type, constraint_name)

Parse the object payload used by a grouped capacity constraint into its concrete, typed config.
Each payload entry is either a legacy type-only group with `edge` and `value`, or a named group
with `select`, `edge`, and `value`. `select` accepts optional `asset_type`, `all`, `any`, and
`exclude` fields. The current grouped capacity constraints all use the shared `GroupConfig` entry
type while retaining separate outer configuration schemas.
"""
function parse_grouped_constraint_config(
    raw::AbstractDict,
    ::Type{C},
    constraint_name::String,
) where {C<:AbstractGroupedConstraintConfig}
    groups = GroupConfig[]
    group_names = Set{Symbol}()

    for (raw_name, raw_group) in raw
        raw_name isa Union{Symbol,AbstractString} || throw(ArgumentError(
            "$constraint_name group name `$raw_name` must be a string.",
        ))
        name = Symbol(raw_name)
        name in group_names && throw(ArgumentError(
            "$constraint_name has a duplicate group `$name`.",
        ))
        push!(group_names, name)

        raw_group isa AbstractDict || throw(ArgumentError(
            "$constraint_name group `$name` must be an object.",
        ))
        group_keys = Set(Symbol(key) for key in keys(raw_group))
        is_explicit_selector = :select in group_keys
        allowed_keys = is_explicit_selector ? Set((:select, :edge, :value)) : Set((:edge, :value))
        unknown_keys = setdiff(group_keys, allowed_keys)
        isempty(unknown_keys) || throw(ArgumentError(
            "$constraint_name group `$name` has unknown key(s): $(collect(unknown_keys)).",
        ))
        haskey(raw_group, :edge) || throw(ArgumentError(
            "$constraint_name group `$name` requires an `edge` key.",
        ))
        haskey(raw_group, :value) || throw(ArgumentError(
            "$constraint_name group `$name` requires a `value` key.",
        ))

        raw_edge = raw_group[:edge]
        raw_edge isa Union{Symbol,AbstractString} || throw(ArgumentError(
            "$constraint_name group `$name` has a non-string `edge`.",
        ))
        raw_value = raw_group[:value]
        raw_value isa Real || throw(ArgumentError(
            "$constraint_name group `$name` has a non-numeric `value`.",
        ))
        value = Float64(raw_value)
        isnan(value) && throw(ArgumentError(
            "$constraint_name group `$name` has an invalid `value`.",
        ))

        selector = is_explicit_selector ?
            parse_group_selector(raw_group[:select], constraint_name, name) :
            parse_legacy_group_selector(raw_name, constraint_name)
        push!(groups, GroupConfig(name, selector, Symbol(raw_edge), value))
    end

    return C(groups)
end

"""
    select_assets(system, selector)

Return the assets that match `selector`. Asset type matching uses the Julia type hierarchy; tag
criteria use the normalized tags stored on each asset.
"""
function select_assets(system::System, selector::GroupSelector)
    asset_type = isnothing(selector.asset_type) ? nothing : get_asset_type(selector.asset_type)
    return filter(system.assets) do asset
        asset_type_matches(asset, asset_type) && tag_selector_matches(asset, selector)
    end
end

function asset_type_matches(asset::AbstractAsset, asset_type)
    isnothing(asset_type) && return true
    return isa(asset, asset_type)
end

function tag_selector_matches(asset::AbstractAsset, selector::GroupSelector)
    tags = asset.tags
    isnothing(tags) && return isempty(selector.all) && isempty(selector.any)
    return all(tag -> tag in tags, selector.all) &&
           (isempty(selector.any) || any(tag -> tag in tags, selector.any)) &&
           all(tag -> !(tag in tags), selector.exclude)
end

function get_asset_type(name::Symbol)
    isdefined(MacroEnergy, name) || throw(ArgumentError("Unknown asset type `$name`."))
    T = getfield(MacroEnergy, name)
    (isa(T, Type) || isa(T, UnionAll)) && T <: AbstractAsset || throw(ArgumentError(
        "`$name` is not an asset type.",
    ))
    return T
end

function parse_group_selector(raw::AbstractDict, constraint_name::String, group_name::Symbol)
    selector_keys = Set(Symbol(key) for key in keys(raw))
    unknown_keys = setdiff(selector_keys, Set((:asset_type, :all, :any, :exclude)))
    isempty(unknown_keys) || throw(ArgumentError(
        "$constraint_name group `$group_name` has unknown selector key(s): $(collect(unknown_keys)).",
    ))
    isempty(selector_keys) && throw(ArgumentError(
        "$constraint_name group `$group_name` requires at least one selector field.",
    ))

    asset_type = if haskey(raw, :asset_type)
        value = raw[:asset_type]
        value isa Union{Symbol,AbstractString} || throw(ArgumentError(
            "$constraint_name group `$group_name` has a non-string `asset_type`.",
        ))
        name = Symbol(value)
        get_asset_type(name)
        name
    else
        nothing
    end
    return GroupSelector(
        asset_type,
        parse_selector_tags(raw, :all, constraint_name, group_name),
        parse_selector_tags(raw, :any, constraint_name, group_name),
        parse_selector_tags(raw, :exclude, constraint_name, group_name),
    )
end

function parse_selector_tags(raw::AbstractDict, key::Symbol, constraint_name::String, group_name::Symbol)
    haskey(raw, key) || return Symbol[]
    tags = raw[key]
    tags isa AbstractVector || throw(ArgumentError(
        "$constraint_name group `$group_name` selector `$key` must be an array of tags.",
    ))
    normalized = Symbol[]
    for tag in tags
        tag isa Union{Symbol,AbstractString} || throw(ArgumentError(
            "$constraint_name group `$group_name` selector `$key` must contain only strings.",
        ))
        push!(normalized, normalize_tag(tag, "$constraint_name group `$group_name` selector `$key`"))
    end
    length(unique(normalized)) == length(normalized) || throw(ArgumentError(
        "$constraint_name group `$group_name` selector `$key` contains duplicate tags.",
    ))
    return normalized
end

function parse_legacy_group_selector(raw_name, constraint_name::String)
    raw_name isa Union{Symbol,AbstractString} || throw(ArgumentError(
        "$constraint_name group name `$raw_name` must be a string.",
    ))
    name = String(raw_name)
    matched = match(r"^([A-Za-z][A-Za-z0-9_]*)\{([^{}]+)\}$", name)
    if !isnothing(matched)
        asset_type = Symbol(matched.captures[1])
        get_asset_type(asset_type)
        return GroupSelector(asset_type, [normalize_tag(matched.captures[2], "legacy selector `$name`")], Symbol[], Symbol[])
    end
    asset_type = Symbol(name)
    get_asset_type(asset_type)
    return GroupSelector(asset_type)
end

# The capacity location is the edge's explicit location when set. Otherwise, use a connected
# vertex, preferring the end vertex (usually the receiving bus) to the start vertex.
function capped_edge_location(e::AbstractEdge)
    ismissing(e.location) || return e.location
    for vertex in (end_vertex(e), start_vertex(e))
        ismissing(location(vertex)) || return location(vertex)
    end
    return missing
end

"""
    build_grouped_capacity_constraints(config, system, model; variable, sense, constraint_name, location)

Build one capacity-like constraint for each group in `config` and return its JuMP references,
keyed by group name. `variable` selects the summed quantity (`capacity` or `new_capacity`).
"""
function build_grouped_capacity_constraints(
    config::AbstractGroupedConstraintConfig,
    system::System,
    model::Model;
    variable::Function,
    sense::Symbol,
    constraint_name::String,
    location::Union{Missing,Symbol}=missing,
)
    refs = Dict{Symbol,Any}()
    for group in constraint_groups(config)
        selector = group_selector(group)
        name = group_name(group)
        assets = select_assets(system, selector)
        if isempty(assets)
            @warn "$constraint_name: group `$name` matched no assets in the system; skipping"
            continue
        end

        edge_field = group_edge(group)
        total = AffExpr(0.0)
        contributed = false
        for asset in assets
            edge_field in fieldnames(typeof(asset)) || error(
                "$constraint_name: group `$name` selected asset $(id(asset)) (`$(get_type(asset))`) without edge field `$edge_field`",
            )
            edge = get_component_by_fieldname(asset, edge_field)
            if !has_capacity(edge)
                @warn "$constraint_name: edge field `$edge_field` of asset $(id(asset)) (`$(get_type(asset))`) has no capacity variable; skipping"
                continue
            end
            ismissing(location) || capped_edge_location(edge) == location || continue
            add_to_expression!(total, variable(edge))
            contributed = true
        end
        contributed || continue

        refs[name] = sense === :leq ?
            @constraint(model, total <= group_value(group)) :
            @constraint(model, total >= group_value(group))
    end
    return refs
end

function scale_grouped_constraint_config(
    config::C,
    factor::Float64,
) where {C<:AbstractGroupedConstraintConfig}
    groups = [
        typeof(group)(group_name(group), group_selector(group), group_edge(group), group_value(group) * factor)
        for group in constraint_groups(config)
    ]
    return C(groups)
end

function add_constraints_by_type!(system::System, model::Model, constraint_type::DataType)

    for n in system.locations
        add_constraints_by_type!(n, model, constraint_type)
    end

    for a in system.assets
        for t in fieldnames(typeof(a))
            add_constraints_by_type!(getfield(a, t), model, constraint_type)
        end
    end

    for c in system.constraints
        if isa(c, constraint_type)
            add_model_constraint!(c, system, model)
        end
    end

    return nothing
end

function add_constraints_by_type!(
    y::Union{AbstractEdge,AbstractVertex},
    model::Model,
    ::Type{C},
) where {C<:AbstractTypeConstraint}
    for c in all_constraints(y)
        if c isa C
            add_model_constraint!(c, y, model)
        end
    end

    return nothing
end

function add_constraints_by_type!(
    location::Location,
    model::Model,
    ::Type{C},
) where {C<:AbstractTypeConstraint}
    for c in all_constraints(location)
        if c isa C
            add_model_constraint!(c, location, model)
        end
    end
    return nothing
end

const CONSTRAINT_TYPES = Dict{Symbol,DataType}()

function register_constraint_types!(m::Module = MacroEnergy)
    empty!(CONSTRAINT_TYPES)
    for (constraint_name, constraint_type) in all_subtypes(m, :AbstractTypeConstraint)
        CONSTRAINT_TYPES[constraint_name] = constraint_type
    end
    return nothing
end

function constraint_types(m::Module = MacroEnergy)
    isempty(CONSTRAINT_TYPES) && register_constraint_types!(m)
    return CONSTRAINT_TYPES
end
