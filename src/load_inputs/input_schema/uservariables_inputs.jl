function _has_uservar_field(var_config::AbstractDict, key::Symbol)
    return haskey(var_config, key) || haskey(var_config, String(key))
end

function _get_uservar_field(var_config::AbstractDict, key::Symbol, default)
    if haskey(var_config, key)
        return var_config[key]
    elseif haskey(var_config, String(key))
        return var_config[String(key)]
    end
    return default
end

function _normalize_user_variable_type(var_type_raw, idx::Int, node_id::Symbol)::Symbol
    if isa(var_type_raw, Symbol)
        var_type = var_type_raw
    elseif isa(var_type_raw, AbstractString)
        var_type = Symbol(var_type_raw)
    else
        error("Variable $idx in node $node_id: 'type' must be a Symbol or String, got $(typeof(var_type_raw))")
    end

    if !(var_type in USER_VARIABLE_TYPES)
        error("Variable $idx in node $node_id: 'type' must be one of $(collect(USER_VARIABLE_TYPES)), got $(var_type)")
    end

    return var_type
end

function _normalize_user_variable_bound(var_bound_raw, bound_name::Symbol, idx::Int, node_id::Symbol)
    if var_bound_raw === nothing
        return nothing
    elseif isa(var_bound_raw, Number)
        return Float64(var_bound_raw)
    end

    error("Variable $idx in node $node_id: '$(bound_name)' must be numeric, got $(typeof(var_bound_raw))")
end

"""
    check_and_convert_uservar(variables_input::Union{AbstractVector, Nothing}, node_id::Symbol)::Dict{Symbol, UserVariable}

Parse and validate user-defined variable specifications from input data.

# Arguments
- `variables_input`: Vector of variable configuration dictionaries, or `nothing`/empty
- `node_id`: Component identifier used in error messages

# Input Format
Each variable in the vector should have the form:
```
{
    :name => <Symbol or String>,       # Optional, defaults to ""
    :time_varying => <Bool>,           # Required
    :operation_variable => <Bool>,     # Optional, defaults to true
    :number_segments => <Int>,         # Optional, defaults to 1
    :type => <Symbol or String>,       # Optional, defaults to "Continuous"
    :lower_bound => <Number>,          # Optional
    :upper_bound => <Number>           # Optional
}
```

# Returns
- `Dict{Symbol, UserVariable}`: Dictionary mapping stored variable keys to their configurations

# Validation
- `name`: Optional, must be `Symbol` or `String` if present; defaults to `""`
- `time_varying`: Required, must be `Bool`
- `operation_variable`: Optional, must be `Bool` if present; defaults to `true`
- `number_segments`: Optional, must be positive `Int` if present; defaults to `1`
- `type`: Optional, must be one of `Continuous`, `Bin`, `Int`, `Semiinteger`, `Semicontinuous`; defaults to `Continuous`
- `lower_bound`/`upper_bound`: Optional, must be numeric if present
- `Semiinteger`/`Semicontinuous` variables require both `lower_bound` and `upper_bound`

If a variable is unnamed, or if the same name is repeated, a unique fallback key
such as `:variable1` is assigned in the returned dictionary.
"""
function check_and_convert_uservar(variables_input::Union{AbstractVector, Nothing}, node_id::Symbol)::Dict{Symbol, UserVariable}
    variables = Dict{Symbol, UserVariable}()
    
    # Handle empty/missing input
    if variables_input === nothing || isempty(variables_input)
        return variables
    end
    
    default_counter = 1
    
    for (idx, var_config) in enumerate(variables_input)
        if !isa(var_config, AbstractDict)
            error("Variable $idx in node $node_id must be a dictionary. Got $(typeof(var_config))")
        end
        
        # Extract name (optional, defaults to "")
        var_name_raw = _get_uservar_field(var_config, :name, "")
        if isa(var_name_raw, Symbol)
            var_name = var_name_raw
        elseif isa(var_name_raw, String)
            var_name = Symbol(var_name_raw)
        else
            error("Variable $idx in node $node_id: 'name' must be a Symbol or String, got $(typeof(var_name_raw))")
        end
        
        # Determine dictionary key: use var_name if unique, otherwise auto-generate
        var_key = var_name
        if var_key == Symbol("") || haskey(variables, var_key)
            while haskey(variables, Symbol("variable$default_counter"))
                default_counter += 1
            end
            var_key = Symbol("variable$default_counter")
            default_counter += 1
        end
        
        # Extract and validate time_varying (required, must be Bool)
        if !_has_uservar_field(var_config, :time_varying)
            error("Variable $idx in node $node_id missing required 'time_varying' field")
        end
        time_varying = _get_uservar_field(var_config, :time_varying, nothing)
        if !isa(time_varying, Bool)
            error("Variable $idx in node $node_id: 'time_varying' must be a Bool, got $(typeof(time_varying))")
        end

        # Extract and validate operation_variable (optional, defaults to true)
        operation_variable = _get_uservar_field(var_config, :operation_variable, true)
        if !isa(operation_variable, Bool)
            error("Variable $idx in node $node_id: 'operation_variable' must be a Bool, got $(typeof(operation_variable))")
        end
        
        # Extract and validate number_segments (optional, defaults to 1)
        number_segments = _get_uservar_field(var_config, :number_segments, 1)
        if !isa(number_segments, Int)
            error("Variable $idx in node $node_id: 'number_segments' must be an Int, got $(typeof(number_segments))")
        end
        if number_segments <= 0
            error("Variable $idx in node $node_id: 'number_segments' must be positive, got $number_segments")
        end

        variable_type = _normalize_user_variable_type(
            _get_uservar_field(var_config, :type, "Continuous"),
            idx,
            node_id,
        )
        lower_bound = _normalize_user_variable_bound(
            _get_uservar_field(var_config, :lower_bound, nothing),
            :lower_bound,
            idx,
            node_id,
        )
        upper_bound = _normalize_user_variable_bound(
            _get_uservar_field(var_config, :upper_bound, nothing),
            :upper_bound,
            idx,
            node_id,
        )

        if lower_bound !== nothing && upper_bound !== nothing && lower_bound > upper_bound
            error("Variable $idx in node $node_id: 'lower_bound' cannot exceed 'upper_bound'")
        end
        if variable_type in (:Semiinteger, :Semicontinuous) &&
           (lower_bound === nothing || upper_bound === nothing)
            error("Variable $idx in node $node_id: '$(variable_type)' variables require both 'lower_bound' and 'upper_bound'")
        end
        
        # Store with var_key, but UserVariable stores the original user-provided name
        variables[var_key] = UserVariable(
            var_name,
            time_varying,
            operation_variable,
            number_segments,
            variable_type,
            lower_bound,
            upper_bound,
            nothing,
        )
    end
    
    return variables
end

"""
    check_and_convert_variables!(data::AbstractDict{Symbol,Any})

Normalize the `:variables` entry in an input dictionary to
`Dict{Symbol,UserVariable}` in-place.

If `data[:variables]` is missing, `nothing`, or empty, it is replaced with an
empty dictionary. If the variables are already parsed as `UserVariable`
instances, the function leaves them unchanged. Otherwise it parses them through
[`check_and_convert_uservar`](@ref).

# Arguments
- `data`: Input dictionary for a component

# Returns
- `nothing`
"""
function check_and_convert_variables!(data::AbstractDict{Symbol,Any})
    node_id = get(data, :id, :unknown)

    if !haskey(data, :variables) || data[:variables] === nothing
        data[:variables] = Dict{Symbol,UserVariable}()
        return nothing
    end

    if isa(data[:variables], AbstractDict)
        if isempty(data[:variables])
            data[:variables] = Dict{Symbol,UserVariable}()
            return nothing
        end

        if all(value -> isa(value, UserVariable), values(data[:variables]))
            return nothing
        end
    end

    data[:variables] = check_and_convert_uservar(data[:variables], Symbol(node_id))
    return nothing
end
