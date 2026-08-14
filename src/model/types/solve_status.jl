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

