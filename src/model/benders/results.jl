"""
    BendersConvergence

A struct to hold convergence diagnostics from a completed Benders solve, including iteration history of lower and upper bounds, optimality gap, termination status, and CPU time.

# Fields
- `LB_hist::Vector{Float64}`: History of lower bounds across iterations.
- `UB_hist::Vector{Float64}`: History of upper bounds across iterations.
- `gap_hist::Vector{Float64}`: History of optimality gap across iterations.
- `termination_status::AbstractString`: Termination status of the Benders solve (e.g. "Optimal", "Infeasible", etc.).
- `cpu_time::Vector{Float64}`: History of CPU time taken for each iteration.
"""
struct BendersConvergence
    LB_hist::Vector{Float64}
    UB_hist::Vector{Float64}
    gap_hist::Vector{Float64}
    termination_status::AbstractString
    cpu_time::Vector{Float64}
end

BendersConvergence(nt::NamedTuple) = BendersConvergence(
    nt.LB_hist, nt.UB_hist, nt.gap_hist, nt.termination_status, nt.cpu_time
)

"""
    BendersModel

A mutable struct to hold all components of a Benders optimization problem.

It mirrors JuMP's `Model` pattern:
- `generate_model` sets up the problem (including subproblem initialization),
- `optimize!` runs the Benders solve, extracts results, and stores them in the `planning_sol`, `subop_sol`, and `convergence` fields.

# Fields
- `settings::NamedTuple`: The case settings loaded from `case_settings.json`.
- `update_target::Union{Case, System}`: The object (case or system) to be updated with the planning solution after optimization (e.g. final capacity values, policy constraints, etc.).
- `planning_problem::Model`: The JuMP model representing the master problem (planning problem).
- `subproblems::Union{Vector{Dict{Any, Any}}, DistributedArrays.DArray}`: A vector (or distributed array) of dictionaries, each containing a JuMP model for a subproblem and its associated data.
- `linking_variables_sub::Dict`: A dictionary of the linking variables in the subproblems that connect to the planning problem.
- `planning_sol::Union{NamedTuple, Nothing}`: A named tuple to hold the solution of the planning problem after optimization.
- `subop_sol::Union{Dict{Any, Any}, Nothing}`: A dictionary to hold the solutions of the subproblems after optimization.
- `convergence::Union{BendersConvergence, Nothing}`: A field to hold the convergence diagnostics after optimization.
"""
mutable struct BendersModel
    settings::NamedTuple
    update_target::Union{Case, System}
    planning_problem::Model
    subproblems::Union{Vector{Dict{Any, Any}}, DistributedArrays.DArray}
    linking_variables_sub::Dict
    planning_sol::Union{NamedTuple, Nothing}
    subop_sol::Union{Dict{Any, Any}, Nothing}
    convergence::Union{BendersConvergence, Nothing}
end

# Convenience constructor for BendersModel when planning_sol, subop_sol, and convergence are not yet available
# they will be populated after optimize! is called
BendersModel(settings, target, planning_problem, subproblems, linking_variables_sub) =
    BendersModel(settings, target, planning_problem, subproblems, linking_variables_sub, nothing, nothing, nothing)