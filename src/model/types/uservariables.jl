"""
    UserVariable

Specification for a user-defined variable attached to a component.

`UserVariable` stores the metadata required to create a JuMP variable on an
`AbstractVertex` or `AbstractEdge`. The `variable_ref` field is populated when
the corresponding planning or operational model is built.

# Fields
- `name::Symbol`: The nonempty, unique variable name within the component.
- `time_varying::Bool`: Whether the variable is indexed over time.
- `operation_variable::Bool`: Whether the variable belongs to the operation model (`true`) or planning model (`false`).
- `number_segments::Int`: Number of segment indices created for the variable.
- `variable_type::Symbol`: Variable type, one of `Continuous`, `Bin`, `Int`, `Semiinteger`, or `Semicontinuous`.
- `lower_bound::Union{Nothing,Float64}`: Optional lower bound.
- `upper_bound::Union{Nothing,Float64}`: Optional upper bound.
- `variable_ref::Union{Nothing,JuMPVariable}`: Reference to the created JuMP variable container, or `nothing` before model creation.
"""
struct UserVariable
    name::Symbol
    time_varying::Bool
    operation_variable::Bool
    number_segments::Int
    variable_type::Symbol
    lower_bound::Union{Nothing,Float64}
    upper_bound::Union{Nothing,Float64}
    variable_ref::Union{Nothing, JuMPVariable}
end

"""
    with_variable_ref(variable::UserVariable, ref)

Return a new immutable `UserVariable` with `ref` as its model reference, preserving
all specification fields. Pass `nothing` to clear the reference. The original
object is unchanged; callers must store the returned object.
"""
function with_variable_ref(variable::UserVariable, ref::Union{Nothing,JuMPVariable})
    return UserVariable(
        variable.name,
        variable.time_varying,
        variable.operation_variable,
        variable.number_segments,
        variable.variable_type,
        variable.lower_bound,
        variable.upper_bound,
        ref,
    )
end

"""
    release_user_variable_references!(component)

Clear user-variable references on an edge or vertex by replacing the immutable
entries in `component.variables`. Preserve all specification fields for rebuilding.
Previously saved entries and references are not modified. Call this helper on
each component before discarding its model. It clears only
user-variable references; it does not empty the JuMP model or release other fields.
"""
function release_user_variable_references!(component::Union{AbstractEdge,AbstractVertex})
    for (name, variable) in component.variables
        if variable.variable_ref !== nothing
            component.variables[name] = with_variable_ref(variable, nothing)
        end
    end
    return nothing
end

"""
    USER_VARIABLE_TYPES

Allowed variable type labels for user-defined variables.
"""
const USER_VARIABLE_TYPES = Set([
    :Continuous,
    :Bin,
    :Int,
    :Semiinteger,
    :Semicontinuous,
])

function _validate_user_variable_names(variables::AbstractDict, component_id)
    for (key, spec) in variables
        isempty(strip(String(spec.name))) &&
            error("User variable on component $component_id must have a nonempty name")
        key isa Symbol && key == spec.name ||
            error("User variable key $key on component $component_id must match its declared name $(spec.name)")
    end
    return nothing
end

"""
    _user_variable_lookup_key(name::Symbol)
    _user_variable_lookup_key(name::AbstractString)

Normalize a user variable identifier to the `Symbol` key format used in the
component `variables` dictionary.
"""
_user_variable_lookup_key(name::Symbol) = name
_user_variable_lookup_key(name::AbstractString) = Symbol(name)

"""
    user_variable_spec(component, name)

Return the [`UserVariable`](@ref) specification for a user-defined variable on a
component.

Names are unique dictionary keys in `component.variables`.

# Arguments
- `component`: An `AbstractVertex` or `AbstractEdge`
- `name`: Variable identifier as a `Symbol` or `String`

# Returns
- The matching `UserVariable`
"""
function user_variable_spec(o::T, name::Union{Symbol,AbstractString}) where T <: Union{AbstractVertex, AbstractEdge}
    lookup_key = _user_variable_lookup_key(name)

    if haskey(o.variables, lookup_key)
        return o.variables[lookup_key]
    end

    error("User variable $(lookup_key) not found on component $(id(o))")
end

"""
    user_variable(component, name)

Return the JuMP variable reference container for a user-defined variable on a
component.

This is a convenience wrapper around [`user_variable_spec`](@ref) that returns
the `variable_ref` field directly. It is intended for the common case where a
user-defined constraint or expression needs the JuMP variable rather than the
full specification. An error is thrown if the variable has not been built or its
reference has been released.

# Arguments
- `component`: An `AbstractVertex` or `AbstractEdge`
- `name`: Variable identifier as a `Symbol` or `String`

# Returns
- The `variable_ref` stored on the matching `UserVariable`
"""
function user_variable(o::T, name::Union{Symbol,AbstractString}) where {T <: Union{AbstractVertex, AbstractEdge}}
    variable = user_variable_spec(o, name)
    variable.variable_ref === nothing &&
        error("User variable $(variable.name) on component $(id(o)) has not been built or has been released")
    return variable.variable_ref
end

"""
    _set_user_variable_attributes!(var_ref, var_config)

Apply variable type and bound attributes to a created JuMP variable container.

This helper is used for user-defined variables that are created as standard JuMP
variables and then modified in-place. Semi-continuous and semi-integer
variables are created directly in their JuMP sets and therefore do not use this
helper.
"""
function _set_user_variable_attributes!(var_ref, var_config::UserVariable)
    for ref in var_ref
        if var_config.lower_bound !== nothing
            JuMP.set_lower_bound(ref, var_config.lower_bound)
        end
        if var_config.upper_bound !== nothing
            JuMP.set_upper_bound(ref, var_config.upper_bound)
        end

        if var_config.variable_type == :Bin
            JuMP.set_binary(ref)
        elseif var_config.variable_type == :Int
            JuMP.set_integer(ref)
        end
    end
    return nothing
end

"""
    add_uservariables!(component, model, operation_variable)

Create all user-defined variables for a component that belong to the specified
model stage.

Variables are read from `component.variables`, created on the provided JuMP
`model`, and written back into the same dictionary with their `variable_ref`
field populated. Variables with `operation_variable == false` are created during
planning-model construction, while variables with `operation_variable == true`
are created during operation-model construction.

The created variable names are based on the unique name stored in
`component.variables`.

Warns if a variable already has valid references in this model. Creation still
proceeds; existing variables and constraints remain in the model, while the
component stores the new references.

# Arguments
- `component`: An `AbstractVertex` or `AbstractEdge`
- `model::Model`: The JuMP model receiving the variables
- `operation_variable::Bool`: The model stage to create, `false` for planning and `true` for operation

# Returns
- `nothing`
"""
function add_uservariables!(o::T, model::Model, operation_variable::Bool) where T <: Union{AbstractVertex, AbstractEdge}
    _validate_user_variable_names(o.variables, id(o))
    for (var_key, var_config) in o.variables
        if var_config.operation_variable == operation_variable
            if var_config.variable_ref !== nothing &&
               any(ref -> JuMP.is_valid(model, ref), var_config.variable_ref)
                @warn "User variable $(var_key) on component $(id(o)) already exists in this model. Creating new variables and replacing the stored references; existing variables and constraints remain in the model."
            end
            # Use the unique declared name for the JuMP variable name.
            var_name = "v$(var_key)_$(id(o))_period$(period_index(o))"
            if var_config.variable_type == :Semiinteger
                var_set = JuMP.Semiinteger(var_config.lower_bound, var_config.upper_bound)
                if var_config.time_varying
                    var_ref = JuMP.@variable(
                        model,
                        [t in time_interval(o), s in 1:var_config.number_segments],
                        set = var_set,
                        base_name = var_name,
                    )
                else
                    var_ref = JuMP.@variable(
                        model,
                        [s in 1:var_config.number_segments],
                        set = var_set,
                        base_name = var_name,
                    )
                end
            elseif var_config.variable_type == :Semicontinuous
                var_set = JuMP.Semicontinuous(var_config.lower_bound, var_config.upper_bound)
                if var_config.time_varying
                    var_ref = JuMP.@variable(
                        model,
                        [t in time_interval(o), s in 1:var_config.number_segments],
                        set = var_set,
                        base_name = var_name,
                    )
                else
                    var_ref = JuMP.@variable(
                        model,
                        [s in 1:var_config.number_segments],
                        set = var_set,
                        base_name = var_name,
                    )
                end
            else
                if var_config.time_varying
                    var_ref = JuMP.@variable(
                        model,
                        [t in time_interval(o), s in 1:var_config.number_segments],
                        base_name = var_name,
                    )
                else
                    var_ref = JuMP.@variable(
                        model,
                        [s in 1:var_config.number_segments],
                        base_name = var_name,
                    )
                end
                _set_user_variable_attributes!(var_ref, var_config)
            end

            o.variables[var_key] = with_variable_ref(var_config, var_ref)
        end
    end
end
