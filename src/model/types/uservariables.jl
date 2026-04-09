struct UserVariable
    name::Symbol
    time_varying::Bool
    operation_variable::Bool
    number_segments::Int
    variable_ref::Union{Nothing, JuMPVariable}
end

function add_uservariables!(o::T, model::Model, operation_variable::Bool) where T <: Union{AbstractVertex, AbstractEdge}
    for (var_key, var_config) in o.variables
        if var_config.operation_variable == operation_variable
            # Use the stored dictionary key so unnamed and duplicate user variables
            # still receive stable, unique JuMP names.
            var_name = "v$(var_key)_$(id(o))_period$(period_index(o))"
            if var_config.time_varying
                var_ref = JuMP.@variable(
                    model, 
                    [t in time_interval(o), s in 1:var_config.number_segments], 
                    base_name=var_name
                )
            else
                var_ref = JuMP.@variable(
                    model, 
                    [s in 1:var_config.number_segments],
                    base_name=var_name
                )
            end
            o.variables[var_key] = UserVariable(var_config.name, var_config.time_varying, var_config.operation_variable, var_config.number_segments, var_ref)
        end
    end
end
