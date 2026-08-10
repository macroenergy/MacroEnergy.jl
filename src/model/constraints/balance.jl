Base.@kwdef mutable struct BalanceConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Dict{Symbol,Vector{Float64}}} = missing
    constraint_ref::Union{Missing,Dict{Symbol,Any}} = missing
end

@doc raw"""
    add_model_constraint!(ct::BalanceConstraint, v::AbstractVertex, model::Model)

Add a balance constraint to the vertex `v`. 

- If `v` is a `Node`, a demand balance constraint is added. 
- If `v` is a `Transformation`, this constraint ensures that the stoichiometric equations linking the input and output flows are correctly balanced.

```math
\begin{aligned}
    \sum_{\substack{i\  \in \ \text{balance\_eqs\_ids(v)}, \\ t\  \in \ \text{time\_interval(v)}} } \text{balance\_eq(v, i, t)} = 0.0
\end{aligned}
```
"""
function add_model_constraint!(ct::BalanceConstraint, v::AbstractVertex, model::Model)
    ct.constraint_ref = Dict{Symbol,Any}()
    for balance_id in keys(v.balance_data)
        sense = balance_sense(v, balance_id)
        if sense == :eq
            ct.constraint_ref[balance_id] = @constraint(
                model,
                [t in time_interval(v)],
                get_balance(v, balance_id, t) == 0.0
            )
        elseif sense == :le
            ct.constraint_ref[balance_id] = @constraint(
                model,
                [t in time_interval(v)],
                get_balance(v, balance_id, t) <= 0.0
            )
        elseif sense == :ge
            ct.constraint_ref[balance_id] = @constraint(
                model,
                [t in time_interval(v)],
                get_balance(v, balance_id, t) >= 0.0
            )
        else
            error("Unsupported balance sense $sense on $(id(v))-$balance_id")
        end
    end

    return nothing
end

"""
    set_constraint_dual!(constraint::BalanceConstraint, v::AbstractVertex)

Extract and store dual values from a BalanceConstraint for all balance equations 
on a given vertex.

# Arguments
- `constraint::BalanceConstraint`: The balance constraint to set the dual values for
- `v::AbstractVertex`: The vertex containing the balance constraint

# Returns
- `nothing`. The dual values are stored in the `constraint_dual` field of the constraint
  as a Dict mapping balance equation IDs (Symbol) to vectors of dual values (Vector{Float64}).

This function extracts dual values from the constraint reference for all balance equations
defined on the vertex (e.g., node or transformation) and stores them in a 
dictionary in the `constraint_dual` field.
"""
function set_constraint_dual!(
    constraint::BalanceConstraint,
    v::AbstractVertex,
)
    # Check if constraint has a reference
    if ismissing(constraint.constraint_ref)
        error("BalanceConstraint on vertex $(id(v)) has no constraint reference")
    end

    # Extract dual values for all balance IDs
    constraint.constraint_dual = Dict{Symbol, Vector{Float64}}()
    for balance_id in keys(v.balance_data)
        constraint.constraint_dual[balance_id] = [
            dual(constraint.constraint_ref[balance_id][t]) for t in time_interval(v)
        ]
    end

    return nothing
end
