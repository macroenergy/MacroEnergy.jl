# MacroEnergy Optimization Container

"""
    MacroEnergyObjectiveFunction
A structure to hold the objective function for MacroEnergy optimization.
"""
mutable struct MacroEnergyObjectiveFunction
    objective_expression::Union{Nothing, AbstractArray}  # The objective expression, can be empty
    sense::Symbol  # The sense of the objective ('Min', 'Max')

    function MacroEnergyObjectiveFunction()
        return new(nothing, :Min)  # Default to an empty objective with 'Min' sense
    end
end

get_objective_sense(v::MacroEnergyObjectiveFunction) = v.sense
set_objective_sense!(v::MacroEnergyObjectiveFunction, sense::Symbol) = v.sense = sense

function MacroEnergyObjectiveFunction(::Nothing)
    return MacroEnergyObjectiveFunction()
end

"""
    MacroEnergyPrimalValuesCache
A cache for primal values of variables in the MacroEnergy optimization container.
"""
mutable struct MacroEnergyPrimalValuesCache
    variable_values::Dict{Symbol, AbstractArray}  # Cached values of variables
    aux_variable_values::Dict{Symbol, AbstractArray}  # Cached values of auxiliary variables
    dual_values::Dict{Symbol, AbstractArray}  # Cached dual values
    
    function MacroEnergyPrimalValuesCache()
        return new(
            Dict{Symbol, AbstractArray}(),
            Dict{Symbol, AbstractArray}(),
            Dict{Symbol, AbstractArray}()
        )
    end
end

"""
    MacroEnergyInitialConditionsData
A structure to hold initial conditions data for the MacroEnergy optimization container.
"""
mutable struct MacroEnergyInitialConditionsData
    initial_conditions::Dict{Symbol, Vector}  # Initial conditions for the optimization container
    initial_conditions_data::Dict{Symbol, Any}  # Additional data related to initial conditions
    
    function MacroEnergyInitialConditionsData()
        return new(
            Dict{Symbol, Vector}(),
            Dict{Symbol, Any}()
        )
    end
end

"""
    MacroEnergyOptimizationContainer{T}
A mutable struct that implements the optimization container interface.
It holds a JuMP model, settings, variables, constraints, objective function, and other related data.
"""
mutable struct MacroEnergyOptimizationContainer{T}
    jump_model::JuMP.Model  # The JuMP model
    settings::Dict{Symbol, Any}
    settings_copy::Dict{Symbol, Any}
    variables::Dict{Symbol, AbstractArray}
    aux_variables::Dict{Symbol, AbstractArray}
    duals::Dict{Symbol, AbstractArray}
    constraints::Dict{Symbol, AbstractArray}
    objective_function::MacroEnergyObjectiveFunction
    expressions::Dict{Symbol, AbstractArray}
    parameters::Dict{Symbol, Any}
    primal_values_cache::MacroEnergyPrimalValuesCache
    initial_conditions::Dict{Symbol, Vector}
    initial_conditions_data::MacroEnergyInitialConditionsData
    metadata::Dict{String, Any}
    
    function MacroEnergyOptimizationContainer{T}() where T
        return new{T}(
            JuMP.Model(),  # Create a new JuMP model
            Dict{Symbol, Any}(),
            Dict{Symbol, Any}(),
            Dict{Symbol, AbstractArray}(),
            Dict{Symbol, AbstractArray}(),
            Dict{Symbol, AbstractArray}(),
            Dict{Symbol, AbstractArray}(),
            MacroEnergyObjectiveFunction(),
            Dict{Symbol, AbstractArray}(),
            Dict{Symbol, Any}(),
            MacroEnergyPrimalValuesCache(),
            Dict{Symbol, Vector}(),
            MacroEnergyInitialConditionsData(),
            Dict{String, Any}()
        )
    end
end

# Constructor without type parameter defaults to Float64
function MacroEnergyOptimizationContainer()
    return MacroEnergyOptimizationContainer{Float64}()
end

# Convenience constructor with a jump model
function create_macro_energy_optimization_container(jump_model::JuMP.Model, ::Type{T} = Float64) where T
    container = MacroEnergyOptimizationContainer{T}()
    container.jump_model = jump_model
    return container
end

# Basic accessor functions
get_jump_model(container::MacroEnergyOptimizationContainer) = container.jump_model
get_settings(container::MacroEnergyOptimizationContainer) = container.settings
get_variables(container::MacroEnergyOptimizationContainer) = container.variables
get_constraints(container::MacroEnergyOptimizationContainer) = container.constraints
get_objective_function(container::MacroEnergyOptimizationContainer) = container.objective_function

# Objective sense accessors
get_objective_sense(container::MacroEnergyOptimizationContainer) = get_objective_sense(container.objective_function)
set_objective_sense!(container::MacroEnergyOptimizationContainer, sense::Symbol) = set_objective_sense!(container.objective_function, sense)
