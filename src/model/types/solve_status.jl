####### Exceptions and status checks for solved models #######

# Classification of MOI termination statuses used by `assert_solved`. The groups are
# mutually exclusive; every status outside them is treated as a failed solve, so a status
# that is not listed here (including any added by a future MOI release) errors rather than
# passing silently. `test/test_solve_status.jl` checks that the groups stay exhaustive.

# Statuses meaning "the solver proved there is no feasible point"
const INFEASIBLE_STATUSES = (
    MOI.INFEASIBLE,
    MOI.LOCALLY_INFEASIBLE,
    MOI.ALMOST_INFEASIBLE,
    # Reported when presolve detects the problem but cannot tell the two cases apart
    MOI.INFEASIBLE_OR_UNBOUNDED,
)

# Statuses meaning "the objective is unbounded below (or the dual is infeasible)"
const UNBOUNDED_STATUSES = (MOI.DUAL_INFEASIBLE, MOI.ALMOST_DUAL_INFEASIBLE)

# Statuses meaning "the solver stopped early", as opposed to "the solver failed".
# If one of these comes with a feasible incumbent, the solution is usable if sub-optimal.
const LIMIT_STATUSES = (
    MOI.ITERATION_LIMIT,
    MOI.TIME_LIMIT,
    MOI.NODE_LIMIT,
    MOI.SOLUTION_LIMIT,
    MOI.MEMORY_LIMIT,
    MOI.OBJECTIVE_LIMIT,
    MOI.NORM_LIMIT,
    MOI.OTHER_LIMIT,
    MOI.SLOW_PROGRESS,
    MOI.INTERRUPTED,
)

# Statuses accepted as a successful solve, all of which `is_solved_and_feasible` covers
# (with `allow_almost = true`) when a feasible primal point is also available
const SOLVED_STATUSES = (
    MOI.OPTIMAL,
    MOI.LOCALLY_SOLVED,
    MOI.ALMOST_OPTIMAL,
    MOI.ALMOST_LOCALLY_SOLVED,
)

# Primal statuses that mean "the point held by the solver is a feasible one"
const FEASIBLE_PRIMAL_STATUSES = (MOI.FEASIBLE_POINT, MOI.NEARLY_FEASIBLE_POINT)

"""
    InfeasibleModel <: Exception

Thrown when the optimizer proves that a model has no feasible solution.

# Fields
- `status::MOI.TerminationStatusCode`: Termination status reported by the optimizer.
- `label::String`: Optional description of which model failed (e.g. `"period 3"`).
"""
struct InfeasibleModel <: Exception
    status::MOI.TerminationStatusCode
    label::String
end

function Base.showerror(io::IO, e::InfeasibleModel)
    print(
        io,
        "Model",
        isempty(e.label) ? "" : " ($(e.label))",
        " is infeasible: termination status $(e.status).",
    )
    if e.status == MOI.INFEASIBLE_OR_UNBOUNDED
        print(
            io,
            " The optimizer could not distinguish an infeasible model from an unbounded one, ",
            "usually because presolve detected the issue. Please check the JuMP documentation for how to disambiguate this case.",
        )
    end
end

"""
    UnboundedModel <: Exception

Thrown when the optimizer reports that a model's objective is unbounded.

# Fields
- `status::MOI.TerminationStatusCode`: Termination status reported by the optimizer.
- `label::String`: Optional description of which model failed (e.g. `"period 3"`).
"""
struct UnboundedModel <: Exception
    status::MOI.TerminationStatusCode
    label::String
end

Base.showerror(io::IO, e::UnboundedModel) = print(
    io,
    "Model",
    isempty(e.label) ? "" : " ($(e.label))",
    " is unbounded: termination status $(e.status). ",
)

"""
    SolveFailed <: Exception

Thrown when the optimizer terminates without a usable primal solution for a reason
other than proven infeasibility (e.g. numerical failure, or a limit reached before any
feasible point was found).

# Fields
- `status::MOI.TerminationStatusCode`: Termination status reported by the optimizer.
- `primal::MOI.ResultStatusCode`: Primal status reported by the optimizer.
- `label::String`: Optional description of which model failed (e.g. `"period 3"`).
"""
struct SolveFailed <: Exception
    status::MOI.TerminationStatusCode
    primal::MOI.ResultStatusCode
    label::String
end

function Base.showerror(io::IO, e::SolveFailed)
    print(
        io,
        "Model",
        isempty(e.label) ? "" : " ($(e.label))",
        " did not solve to optimality: termination status $(e.status), primal status $(e.primal). ",
    )
    # A failure status can still come with a point attached — a numerical error, for
    # instance, leaves whatever the solver had reached.
    if e.primal in FEASIBLE_PRIMAL_STATUSES
        print(
            io,
            "A point is available, but the solver did not report a successful termination, ",
            "so it is not used and no results are written.",
        )
    else
        print(io, "No solution is available, so results cannot be written.")
    end
end

