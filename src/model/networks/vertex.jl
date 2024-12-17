"""
    @AbstractVertexBaseAttributes()

    A macro that defines the base attributes for all vertex types in the network model.

    # Generated Fields
    - id::Symbol: Unique identifier for the vertex
    - timedata::TimeData: Time-related data for the vertex
    - balance_data::Dict{Symbol,Dict{Symbol,Float64}}: Dictionary mapping balance equation IDs to coefficients
    - constraints::Vector{AbstractTypeConstraint}: List of constraints applied to the vertex
    - operation_expr::Dict: Dictionary storing operational JuMP expressions for the vertex

    This macro is used to ensure consistent base attributes across all vertex types in the network.
"""
macro AbstractVertexBaseAttributes()
    esc(
        quote
            id::Symbol
            timedata::TimeData

            balance_data::Dict{Symbol,Dict{Symbol,Float64}} =
                Dict{Symbol,Dict{Symbol,Float64}}()
            constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
            operation_expr::Dict = Dict()
        end,
    )
end

id(v::AbstractVertex) = v.id;
balance_ids(v::AbstractVertex) = collect(keys(v.balance_data));
balance_data(v::AbstractVertex, i::Symbol) = v.balance_data[i];

get_balance(v::AbstractVertex, i::Symbol) = v.operation_expr[i];
get_balance(v::AbstractVertex, i::Symbol, t::Int64) = get_balance(v, i)[t];

all_constraints(v::AbstractVertex) = v.constraints;
