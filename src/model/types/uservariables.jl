"""
    UserVariable

Specification for a user-defined variable attached to a component.

`UserVariable` stores the metadata required to create a JuMP variable on an
`AbstractVertex` or `AbstractEdge`. The `variable_ref` field is populated when
the corresponding planning or operational model is built.

# Fields
- `name::Symbol`: The user-provided variable name, if any.
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

Lookup first checks for an exact dictionary key match in `component.variables`.
If that fails, it searches for a unique variable whose stored `name` matches the
requested identifier. If multiple variables share the same stored name, an error
is thrown so the caller can disambiguate by explicit key.

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

    matching_keys = [var_key for (var_key, var_config) in o.variables if var_config.name == lookup_key]
    if length(matching_keys) == 1
        return o.variables[only(matching_keys)]
    elseif length(matching_keys) > 1
        error("User variable $(lookup_key) is ambiguous on component $(id(o)); use one of the explicit keys $(matching_keys)")
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
full specification.

# Arguments
- `component`: An `AbstractVertex` or `AbstractEdge`
- `name`: Variable identifier as a `Symbol` or `String`

# Returns
- The `variable_ref` stored on the matching `UserVariable`
"""
user_variable(o::T, name::Union{Symbol,AbstractString}) where {T <: Union{AbstractVertex, AbstractEdge}} =
    user_variable_spec(o, name).variable_ref

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

The created variable names are based on the dictionary key stored in
`component.variables`, which ensures stable JuMP names even for unnamed or
duplicate user variables.

# Arguments
- `component`: An `AbstractVertex` or `AbstractEdge`
- `model::Model`: The JuMP model receiving the variables
- `operation_variable::Bool`: The model stage to create, `false` for planning and `true` for operation

# Returns
- `nothing`
"""
function add_uservariables!(o::T, model::Model, operation_variable::Bool) where T <: Union{AbstractVertex, AbstractEdge}
    for (var_key, var_config) in o.variables
        if var_config.operation_variable == operation_variable
            # Use the stored dictionary key so unnamed and duplicate user variables
            # still receive stable, unique JuMP names.
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

            o.variables[var_key] = UserVariable(
                var_config.name,
                var_config.time_varying,
                var_config.operation_variable,
                var_config.number_segments,
                var_config.variable_type,
                var_config.lower_bound,
                var_config.upper_bound,
                var_ref,
            )
        end
    end
end
