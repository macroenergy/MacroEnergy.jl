module TestRunStatus

using Test
using HiGHS
using JuMP
import MacroEnergy:
    BendersConvergence,
    BendersModel,
    InfeasibleModel,
    MyopicResults,
    PeriodOutcome,
    SolveFailed,
    UnboundedModel,
    empty_system,
    read_json,
    solution_outcome,
    run_case,
    run_status_failure,
    run_status_running,
    run_status_success,
    set_logger,
    write_run_status

include("utilities.jl")

const test_path = joinpath(@__DIR__, "test_small_case")
const optim = HiGHS.Optimizer

set_logger(true, true, Logging.Error, joinpath(test_path, "test_run_status.log"))

function solved_model()
    model = Model(optim)
    set_silent(model)
    @variable(model, x >= 1)
    @objective(model, Min, x)
    optimize!(model)
    return model
end

# A model whose termination and primal statuses are set directly, to reach outcomes a solver
# only produces under specific conditions
function mock_solved_model(term::MOI.TerminationStatusCode, primal::MOI.ResultStatusCode)
    mock = MOI.Utilities.MockOptimizer(MOI.Utilities.Model{Float64}())
    model = direct_model(mock)
    @variable(model, x >= 0)
    @objective(model, Min, x)
    MOI.set(mock, MOI.TerminationStatus(), term)
    MOI.set(mock, MOI.ResultCount(), primal == MOI.NO_SOLUTION ? 0 : 1)
    MOI.set(mock, MOI.PrimalStatus(), primal)
    MOI.Utilities.set_mock_optimize!(mock, m -> nothing)
    return model
end

function test_status_payload_success()
    @testset "run_status_success payload" begin
        data = run_status_success("/some/case", 12.3456, "/some/case/results", solved_model())

        @test data["status"] == "OK"
        @test data["case_path"] == abspath("/some/case")
        @test data["output_path"] == abspath("/some/case/results")
        @test data["elapsed_seconds"] == 12.346
        @test data["termination_status"] == "OPTIMAL"
        @test haskey(data, "timestamp")
    end
end

function test_status_payload_suboptimal()
    @testset "run_status_success reports a sub-optimal solve" begin
        # A run that stops at its time limit with a usable incumbent must not be recorded
        # the same way as one that converged: the log warning is the only other signal
        model = mock_solved_model(MOI.TIME_LIMIT, MOI.FEASIBLE_POINT)
        data = run_status_success("/some/case", 1.0, "/some/case/results", model)

        @test data["status"] == "SUBOPTIMAL"
        @test data["termination_status"] == "TIME_LIMIT"
    end
end

# `solution_outcome` only reads the convergence field, so the rest of the Benders model is
# filled with empty stand-ins
function benders_model_with_status(status::AbstractString)
    bm = BendersModel(
        (;), empty_system(@__DIR__), Model(), Dict{Any,Any}[], Dict()
    )
    bm.convergence = BendersConvergence(Float64[], Float64[], Float64[], status, Float64[])
    return bm
end

function test_myopic_outcomes()
    @testset "Myopic status comes from recorded per-period outcomes" begin
        # `ReturnModels` is off by default, so `MyopicResults.results` is `nothing` and the
        # per-period outcomes recorded during the solve are the only thing left to report
        all_solved = MyopicResults(
            nothing,
            "/some/case/results",
            [PeriodOutcome(1, "OK", "OPTIMAL"), PeriodOutcome(2, "OK", "OPTIMAL")],
        )
        data = run_status_success("/some/case", 1.0, "/some/case/results", all_solved)
        @test data["status"] == "OK"
        @test data["termination_status"] == "1: OPTIMAL, 2: OPTIMAL"

        # One bad period decides the overall status, even with models discarded
        one_limited = MyopicResults(
            nothing,
            "/some/case/results",
            [PeriodOutcome(1, "OK", "OPTIMAL"), PeriodOutcome(2, "SUBOPTIMAL", "TIME_LIMIT")],
        )
        limited = run_status_success("/some/case", 1.0, "/some/case/results", one_limited)
        @test limited["status"] == "SUBOPTIMAL"
        @test limited["termination_status"] == "1: OPTIMAL, 2: TIME_LIMIT"

        # A period whose Benders solve contradicted itself must not be flattened into
        # SUBOPTIMAL, which tells a consumer the results are usable
        one_failed = MyopicResults(
            nothing,
            "/some/case/results",
            [
                PeriodOutcome(1, "OK", "OPTIMAL"),
                PeriodOutcome(2, "SUBOPTIMAL", "MAXITER"),
                PeriodOutcome(3, "SOLVE_FAILED", "NEGATIVE GAP"),
            ],
        )
        failed = run_status_success("/some/case", 1.0, "/some/case/results", one_failed)
        @test failed["status"] == "SOLVE_FAILED"

        # Restart and StopAfterPeriod skip periods, so entries carry their period number
        # rather than relying on position
        restarted = MyopicResults(
            nothing, "/some/case/results", [PeriodOutcome(3, "SUBOPTIMAL", "TIME_LIMIT")]
        )
        skipped = run_status_success("/some/case", 1.0, "/some/case/results", restarted)
        @test skipped["termination_status"] == "3: TIME_LIMIT"
    end
end

function test_benders_negative_gap()
    @testset "Benders inconsistent bounds are not reported as usable" begin
        for status in ("NEGATIVE GAP", "NONE")
            outcome = solution_outcome(benders_model_with_status(status))
            @test outcome.status == "SOLVE_FAILED"
            @test outcome.termination_status == status
        end

        @test solution_outcome(benders_model_with_status("OPTIMAL")).status == "OK"
        @test solution_outcome(benders_model_with_status("MAXITER")).status == "SUBOPTIMAL"
        @test solution_outcome(benders_model_with_status("TIMELIMIT")).status == "SUBOPTIMAL"
    end
end

function test_status_payload_running()
    @testset "run_status_running payload" begin
        data = run_status_running("/some/case")

        @test data["status"] == "RUNNING"
        @test data["case_path"] == abspath("/some/case")
        @test haskey(data, "timestamp")
        @test !haskey(data, "output_path")
    end
end

function test_status_payload_failures()
    @testset "run_status_failure payload" begin
        infeasible = run_status_failure(
            "/some/case", 1.0, InfeasibleModel(MOI.INFEASIBLE, "period 3")
        )
        @test infeasible["status"] == "INFEASIBLE"
        @test infeasible["exception"] == "InfeasibleModel"
        @test infeasible["termination_status"] == "INFEASIBLE"
        @test infeasible["label"] == "period 3"
        @test occursin("infeasible", infeasible["message"])

        ambiguous = run_status_failure(
            "/some/case", 1.0, InfeasibleModel(MOI.INFEASIBLE_OR_UNBOUNDED, "")
        )
        @test ambiguous["status"] == "INFEASIBLE_OR_UNBOUNDED"
        @test ambiguous["termination_status"] == "INFEASIBLE_OR_UNBOUNDED"

        unbounded = run_status_failure(
            "/some/case", 1.0, UnboundedModel(MOI.DUAL_INFEASIBLE, "")
        )
        @test unbounded["status"] == "UNBOUNDED"
        @test unbounded["termination_status"] == "DUAL_INFEASIBLE"

        failed = run_status_failure(
            "/some/case", 1.0, SolveFailed(MOI.NUMERICAL_ERROR, MOI.NO_SOLUTION, "")
        )
        @test failed["status"] == "SOLVE_FAILED"
        @test failed["primal_status"] == "NO_SOLUTION"

        # Anything that is not a solver outcome is reported as a plain error, without the
        # solver-specific fields, so a caller can branch on "status" alone
        other = run_status_failure("/some/case", 1.0, ErrorException("bad input"))
        @test other["status"] == "ERROR"
        @test other["exception"] == "ErrorException"
        @test occursin("bad input", other["message"])
        @test !haskey(other, "termination_status")
        @test !haskey(other, "primal_status")
    end
end

function test_write_run_status()
    @testset "write_run_status round-trips as JSON" begin
        mktempdir() do dir
            path = joinpath(dir, "run_status.json")
            data = run_status_failure(dir, 2.0, InfeasibleModel(MOI.INFEASIBLE, "period 1"))

            @test write_run_status(path, data) === nothing
            @test isfile(path)

            written = read_json(path)
            @test written.status == "INFEASIBLE"
            @test written.termination_status == "INFEASIBLE"
            @test written.label == "period 1"

            # Replacing an existing file leaves no temporary files behind
            @test write_run_status(path, run_status_running(dir)) === nothing
            @test read_json(path).status == "RUNNING"
            @test readdir(dir) == ["run_status.json"]
        end
    end
end

function test_write_run_status_requires_existing_directory()
    @testset "write_run_status does not create directories" begin
        mktempdir() do dir
            # Creating directories from the status writer would silently produce a case
            # directory for a mistyped path
            missing_dir = joinpath(dir, "not_created")
            path = joinpath(missing_dir, "run_status.json")

            @test (@test_logs (:warn, r"Could not write the run status file") write_run_status(
                path, run_status_running(dir)
            )) === nothing
            @test !isdir(missing_dir)
        end
    end
end

function test_write_run_status_never_throws()
    @testset "write_run_status warns instead of throwing" begin
        mktempdir() do dir
            # A file where a directory would have to be: writing must fail, but the status
            # writer runs on the error path and must not replace the exception being reported
            blocker = joinpath(dir, "blocked")
            write(blocker, "not a directory")
            path = joinpath(blocker, "run_status.json")

            data = run_status_running(dir)
            @test (@test_logs (:warn, r"Could not write the run status file") write_run_status(path, data)) ===
                  nothing
            @test !isfile(path)
        end
    end
end

struct ExplodingError <: Exception end
Base.showerror(io::IO, ::ExplodingError) = error("showerror itself is broken")

function test_write_run_status_guards_payload_construction()
    @testset "write_run_status guards payload construction" begin
        mktempdir() do dir
            path = joinpath(dir, "run_status.json")

            # If building the payload throws, the writer must swallow it too. In `run_case`
            # this runs inside a catch block, so anything escaping here would replace the
            # exception the user actually needs to see
            @test (@test_logs (:warn, r"Could not write the run status file") write_run_status(
                path,
                () -> run_status_failure(dir, 1.0, ExplodingError()),
            )) === nothing
            @test !isfile(path)
        end
    end
end

function test_status_message_is_bounded()
    @testset "Status message is bounded" begin
        # A parse error can echo an entire input file; the status file must stay small
        huge = ErrorException("x"^100_000)
        data = run_status_failure("/some/case", 1.0, huge)

        @test length(data["message"]) < 1_100  # the cap plus the truncation notice
        @test occursin("truncated", data["message"])

        short = run_status_failure("/some/case", 1.0, ErrorException("small problem"))
        @test !occursin("truncated", short["message"])
        @test occursin("small problem", short["message"])
    end
end

function test_run_case_writes_status_on_success()
    @testset "run_case writes an ok status" begin
        mktempdir() do dir
            case_dir = joinpath(dir, "case")
            cp(test_path, case_dir)

            result = @warn_error_logger run_case(
                case_dir; log_to_console = false, log_to_file = false
            )
            # run_case still returns (case, solution), even though the internal
            # implementation now also passes the output path back up
            @test length(result) == 2

            status_path = joinpath(case_dir, "run_status.json")
            @test isfile(status_path)

            status = read_json(status_path)
            @test status.status == "OK"
            @test status.case_path == abspath(case_dir)
            @test isdir(status.output_path)  # results really landed where the file says
            @test status.elapsed_seconds > 0

            # The results directory keeps its own copy, so a later run overwriting the
            # case-level file does not erase the record of this one
            results_copy = joinpath(status.output_path, "run_status.json")
            @test isfile(results_copy)
            @test read_json(results_copy).status == "OK"
        end
    end
end

function test_run_case_writes_status_on_error()
    @testset "run_case writes an error status and still throws" begin
        mktempdir() do dir
            # An empty directory is not a case: loading fails before any solve, which is the
            # failure mode the "error" status exists to distinguish from an infeasible solve
            @test_throws Exception @error_logger run_case(
                dir; log_to_console = false, log_to_file = false
            )

            status_path = joinpath(dir, "run_status.json")
            @test isfile(status_path)

            status = read_json(status_path)
            @test status.status == "ERROR"
            @test !isempty(status.message)
        end
    end
end

function test_run_case_status_can_be_disabled()
    @testset "run_case status file can be disabled" begin
        mktempdir() do dir
            @test_throws Exception @error_logger run_case(
                dir; log_to_console = false, log_to_file = false, write_status = false
            )
            @test !isfile(joinpath(dir, "run_status.json"))
        end
    end
end

test_status_payload_success()
test_status_payload_suboptimal()
test_myopic_outcomes()
test_benders_negative_gap()
test_status_payload_running()
test_status_payload_failures()
test_write_run_status()
test_write_run_status_requires_existing_directory()
test_write_run_status_never_throws()
test_write_run_status_guards_payload_construction()
test_status_message_is_bounded()
test_run_case_writes_status_on_success()
test_run_case_writes_status_on_error()
test_run_case_status_can_be_disabled()

end # module TestRunStatus
