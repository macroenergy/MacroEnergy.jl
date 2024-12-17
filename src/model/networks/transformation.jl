"""
    Transformation <: AbstractVertex

    A mutable struct representing a transformation vertex in a network model, which models a conversion process between different commodities or energy forms.

    # Inherited Attributes
    - id::Symbol: Unique identifier for the transformation
    - timedata::TimeData: Time-related data for the transformation
    - balance_data::Dict{Symbol,Dict{Symbol,Float64}}: Dictionary mapping stoichiometric equation IDs to coefficients
    - constraints::Vector{AbstractTypeConstraint}: List of constraints applied to the transformation
    - operation_expr::Dict: Dictionary storing operational JuMP expressions for the transformation

    Transformations are used to model conversion processes between different commodities, such as power plants 
    converting fuel to electricity or electrolyzers converting electricity to hydrogen. The `balance_data` field 
    typically contains conversion efficiencies and other relationships between input and output flows.
"""
Base.@kwdef mutable struct Transformation <: AbstractVertex
    @AbstractVertexBaseAttributes()
end

function add_linking_variables!(g::Transformation, model::Model)
    return nothing
end

function planning_model!(g::Transformation, model::Model)

    return nothing
end

function define_available_capacity!(g::Transformation, model::Model)
    return nothing
end

function operation_model!(g::Transformation, model::Model)
    if !isempty(balance_ids(g))
        for i in balance_ids(g)
            g.operation_expr[i] =
                @expression(model, [t in time_interval(g)], 0 * model[:vREF])
        end
    end
    return nothing
end
