"""
    check_and_convert_uservar(variables_input::Union{Vector, Nothing}, node_id::Symbol)::Dict{Symbol, UserVariable}

Parse and validate user-defined variables from input data.

# Arguments
- `variables_input`: Vector of variable configuration dictionaries, or nothing/empty
- `node_id`: Node identifier for error messages

# Input Format
Each variable in the vector should have the form:
```
{
    :name => <Symbol or String>,       # Optional, defaults to ""
    :time_varying => <Bool>,           # Required
    :operation_variable => <Bool>,     # Optional, defaults to true
    :number_segments => <Int>          # Optional, defaults to 1
}
```

# Returns
- `Dict{Symbol, UserVariable}`: Dictionary mapping variable names to their configurations

# Validation
- `name`: Optional, must be Symbol or String if present; defaults to ""
- `time_varying`: Required, must be Bool
- `operation_variable`: Optional, must be Bool if present; defaults to true
- `number_segments`: Optional, must be positive Int if present; defaults to 1
- Ensures unique variable names across the node
"""
function check_and_convert_uservar(variables_input::Union{Vector, Nothing}, node_id::Symbol)::Dict{Symbol, UserVariable}
    variables = Dict{Symbol, UserVariable}()
    
    # Handle empty/missing input
    if variables_input === nothing || isempty(variables_input)
        return variables
    end
    
    default_counter = 1
    
    for (idx, var_config) in enumerate(variables_input)
        if !isa(var_config, Dict)
            error("Variable $idx in node $node_id must be a dictionary. Got $(typeof(var_config))")
        end
        
        # Extract name (optional, defaults to "")
        var_name_raw = get(var_config, :name, "")
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
        if !haskey(var_config, :time_varying)
            error("Variable $idx in node $node_id missing required 'time_varying' field")
        end
        time_varying = var_config[:time_varying]
        if !isa(time_varying, Bool)
            error("Variable $idx in node $node_id: 'time_varying' must be a Bool, got $(typeof(time_varying))")
        end

        # Extract and validate operation_variable (optional, defaults to true)
        operation_variable = get(var_config, :operation_variable, true)
        if !isa(operation_variable, Bool)
            error("Variable $idx in node $node_id: 'operation_variable' must be a Bool, got $(typeof(operation_variable))")
        end
        
        # Extract and validate number_segments (optional, defaults to 1)
        number_segments = get(var_config, :number_segments, 1)
        if !isa(number_segments, Int)
            error("Variable $idx in node $node_id: 'number_segments' must be an Int, got $(typeof(number_segments))")
        end
        if number_segments <= 0
            error("Variable $idx in node $node_id: 'number_segments' must be positive, got $number_segments")
        end
        
        # Store with var_key, but UserVariable stores the original user-provided name
        variables[var_key] = UserVariable(var_name, time_varying, operation_variable, number_segments, nothing)
    end
    
    return variables
end

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
