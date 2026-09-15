module TestSolveStatus

using Test
using HiGHS
using JuMP  # also brings JuMP's re-exported MOI into scope
import MacroEnergy:
    INFEASIBLE_STATUSES,
    LIMIT_STATUSES,
    SOLVED_STATUSES,
    UNBOUNDED_STATUSES,
    InfeasibleModel,
    SolveFailed,
    UnboundedModel,
    assert_solved,
    create_optimizer,
    generate_model,
    load_case,
    set_logger,
    solution_algorithm

include("utilities.jl")

const test_path = joinpath(@__DIR__, "test_small_case")
const optim = HiGHS.Optimizer

set_logger(true, true, Logging.Error, joinpath(test_path, "test_solve_status.log"))

# Build a model whose termination and primal statuses we control exactly
function mock_solved_model(
    term_status::MOI.TerminationStatusCode,
    primal_status::MOI.ResultStatusCode,
)
    mock = MOI.Utilities.MockOptimizer(MOI.Utilities.Model{Float64}())
    model = direct_model(mock)
    @variable(model, x >= 0)
    @objective(model, Min, x)
    MOI.set(mock, MOI.TerminationStatus(), term_status)
    MOI.set(mock, MOI.ResultCount(), primal_status == MOI.NO_SOLUTION ? 0 : 1)
    MOI.set(mock, MOI.PrimalStatus(), primal_status)
    MOI.Utilities.set_mock_optimize!(mock, m -> nothing)
    return model
end

function test_assert_solved_optimal()
    @testset "assert_solved accepts an optimal model" begin
        model = Model(optim)
        set_silent(model)
        @variable(model, x >= 1)
        @objective(model, Min, x)
        optimize!(model)

        @test termination_status(model) == MOI.OPTIMAL
        @test assert_solved(model) === nothing
        @test @test_logs assert_solved(model) === nothing  # no warning
    end
end

function test_assert_solved_infeasible()
    @testset "assert_solved rejects an infeasible model" begin
        model = Model(optim)
        set_silent(model)
        @variable(model, x >= 1)
        @constraint(model, x <= 0)
        @objective(model, Min, x)
        optimize!(model)

        @test termination_status(model) in
              (MOI.INFEASIBLE, MOI.INFEASIBLE_OR_UNBOUNDED, MOI.LOCALLY_INFEASIBLE)
        @test_throws InfeasibleModel assert_solved(model)

        err = try
            assert_solved(model; label = "period 2")
            nothing
        catch e
            e
        end
        @test err isa InfeasibleModel
        @test err.status == termination_status(model)
        @test err.label == "period 2"
    end
end

function test_assert_solved_unbounded()
    @testset "assert_solved rejects an unbounded model" begin
        model = Model(optim)
        set_silent(model)
        @variable(model, x)
        @objective(model, Min, x)
        optimize!(model)

        @test termination_status(model) in (UNBOUNDED_STATUSES..., INFEASIBLE_STATUSES...)
        @test_throws Union{UnboundedModel,InfeasibleModel} assert_solved(model)
    end
end

function test_assert_solved_unbounded_mock()
    @testset "assert_solved reports an unbounded model specifically" begin
        model = mock_solved_model(MOI.DUAL_INFEASIBLE, MOI.FEASIBLE_POINT)

        err = try
            assert_solved(model; label = "period 4")
            nothing
        catch e
            e
        end
        @test err isa UnboundedModel
        @test err.status == MOI.DUAL_INFEASIBLE
        @test err.label == "period 4"
    end
end

# The four status groups drive every branch of assert_solved, so they must stay mutually
# exclusive and cover the whole enum. A status MOI adds later shows up here as a failure,
# which is the prompt to classify it rather than let it fall through to SolveFailed silently.
function test_status_groups_are_exhaustive()
    @testset "Status groups cover MOI.TerminationStatusCode" begin
        groups = (SOLVED_STATUSES, INFEASIBLE_STATUSES, UNBOUNDED_STATUSES, LIMIT_STATUSES)
        # Statuses deliberately left to the SolveFailed catch-all: the solver either failed
        # or was never run, and neither leaves a usable solution behind
        failure_statuses = (
            MOI.OPTIMIZE_NOT_CALLED,
            MOI.NUMERICAL_ERROR,
            MOI.INVALID_MODEL,
            MOI.INVALID_OPTION,
            MOI.OTHER_ERROR,
        )

        classified = vcat(collect.(groups)..., collect(failure_statuses))
        @test length(classified) == length(unique(classified))  # groups are disjoint

        for status in instances(MOI.TerminationStatusCode)
            @test count(g -> status in g, (groups..., failure_statuses)) == 1
        end
    end
end

function test_assert_solved_no_solution()
    @testset "assert_solved rejects a failed solve with no solution" begin
        model = mock_solved_model(MOI.NUMERICAL_ERROR, MOI.NO_SOLUTION)

        err = try
            assert_solved(model; label = "period 1")
            nothing
        catch e
            e
        end
        @test err isa SolveFailed
        @test err.status == MOI.NUMERICAL_ERROR
        @test err.primal == MOI.NO_SOLUTION
        @test err.label == "period 1"
    end
end

function test_assert_solved_limit_with_incumbent()
    @testset "assert_solved warns but accepts a limit hit with an incumbent" begin
        model = mock_solved_model(MOI.TIME_LIMIT, MOI.FEASIBLE_POINT)

        @test has_values(model)
        @test_logs (:warn, r"terminated with status TIME_LIMIT") assert_solved(model)
        @test (@test_logs (:warn, r"TIME_LIMIT") assert_solved(model)) === nothing
    end
end

function test_assert_solved_requires_a_feasible_point()
    @testset "assert_solved rejects a solve without a feasible point" begin
        # `has_values` is only `primal_status != NO_SOLUTION`, so it is also true for an
        # infeasible iterate and for an infeasibility certificate
        for primal in (
            MOI.INFEASIBLE_POINT,
            MOI.INFEASIBILITY_CERTIFICATE,
            MOI.UNKNOWN_RESULT_STATUS,
            MOI.OTHER_RESULT_STATUS,
        )
            model = mock_solved_model(MOI.TIME_LIMIT, primal)
            @test has_values(model)
            @test_throws SolveFailed assert_solved(model)
        end

        # A genuinely feasible incumbent is accepted whatever the termination status
        for status in (MOI.TIME_LIMIT, MOI.OTHER_ERROR, MOI.SLOW_PROGRESS, MOI.NUMERICAL_ERROR)
            for primal in (MOI.FEASIBLE_POINT, MOI.NEARLY_FEASIBLE_POINT)
                model = mock_solved_model(status, primal)
                @test (@test_logs (:warn, r"terminated with status") assert_solved(model)) ===
                      nothing
            end
        end
    end
end

function test_error_messages()
    @testset "Error messages" begin
        msg = sprint(showerror, InfeasibleModel(MOI.INFEASIBLE, ""))
        @test occursin("Model is infeasible", msg)
        @test occursin("INFEASIBLE", msg)
        # No ambiguity hint when the solver was unambiguous
        @test !occursin("could not distinguish", msg)

        labelled = sprint(showerror, InfeasibleModel(MOI.INFEASIBLE, "period 3"))
        @test occursin("period 3", labelled)

        # INFEASIBLE_OR_UNBOUNDED is what a barrier solve without crossover typically
        # reports, so the message must say the two cases were not told apart
        ambiguous = sprint(showerror, InfeasibleModel(MOI.INFEASIBLE_OR_UNBOUNDED, ""))
        @test occursin("could not distinguish", ambiguous)
        @test occursin("presolve", ambiguous)

        unbounded = sprint(showerror, UnboundedModel(MOI.DUAL_INFEASIBLE, "period 3"))
        @test occursin("period 3", unbounded)
        @test occursin("unbounded", unbounded)
        @test occursin("DUAL_INFEASIBLE", unbounded)

        failed = sprint(showerror, SolveFailed(MOI.NUMERICAL_ERROR, MOI.NO_SOLUTION, "period 3"))
        @test occursin("period 3", failed)
        @test occursin("No solution is available", failed)
        @test occursin("NUMERICAL_ERROR", failed)

        # A failure status can still carry a point: the message must not claim otherwise
        with_point = sprint(showerror, SolveFailed(MOI.NUMERICAL_ERROR, MOI.FEASIBLE_POINT, ""))
        @test occursin("A point is available", with_point)
        @test !occursin("No solution is available", with_point)
        @test occursin("NO_SOLUTION", failed)
    end
end

function test_assert_solved_on_case_model()
    @testset "assert_solved on a generated case model" begin
        case = @warn_error_logger load_case(test_path);
        alg = solution_algorithm(case)
        model = @warn_error_logger generate_model(case, create_optimizer(optim), alg)
        set_silent(model)

        optimize!(model)
        @test assert_solved(model) === nothing

        # Force infeasibility with two contradictory constraints on a real model variable,
        # independently of that variable's own bounds
        v = first(all_variables(model))
        @constraint(model, v >= 1)
        @constraint(model, v <= -1)
        optimize!(model)

        @test_throws InfeasibleModel assert_solved(model)
    end
end

test_assert_solved_optimal()
test_assert_solved_infeasible()
test_assert_solved_unbounded()
test_assert_solved_unbounded_mock()
test_assert_solved_no_solution()
test_assert_solved_limit_with_incumbent()
test_assert_solved_requires_a_feasible_point()
test_status_groups_are_exhaustive()
test_error_messages()
test_assert_solved_on_case_model()

end # module TestSolveStatus
