####### Status checks for solved models #######
# The exception types and status groups these use live in `model/types/solve_status.jl`

"""
    assert_solved(model::Model; label::AbstractString = "")

Check that `model` has been solved to (near-)optimality and holds a usable primal
solution, and throw a descriptive exception otherwise.

# Arguments
- `model::Model`: The JuMP model to check, after `optimize!`.

# Keyword Arguments
- `label::AbstractString=""`: Description of the model included in error messages, used to
  identify which model failed when several are solved in sequence (e.g. `"period 3"`).

# Returns
- `nothing` if the model has a usable solution.

# Throws
- [`InfeasibleModel`](@ref): For any status in `INFEASIBLE_STATUSES`, i.e. the optimizer
  proved the model infeasible. This covers `MOI.INFEASIBLE_OR_UNBOUNDED`, which is what
  solvers commonly report when presolve detects infeasibility.
- [`UnboundedModel`](@ref): For any status in `UNBOUNDED_STATUSES`.
- [`SolveFailed`](@ref): For any other status without a usable primal solution, including
  numerical failures, an invalid model, and limits hit before a feasible point was found.

# Notes
- Statuses close to optimal (`MOI.ALMOST_OPTIMAL` etc.) are accepted, since the
  default optimizer attributes solve to a loose barrier tolerance without crossover.
- Anything else that still carries a feasible point is accepted with a warning, whatever the
  termination status.
- The result is that only two things throw: a model the solver proved has no solution, and a
  solve that left nothing usable behind.
"""
function assert_solved(model::Model; label::AbstractString = "")
    is_solved_and_feasible(model; allow_almost = true) && return nothing

    status = termination_status(model)

    status in INFEASIBLE_STATUSES && throw(InfeasibleModel(status, label))
    status in UNBOUNDED_STATUSES && throw(UnboundedModel(status, label))

    if primal_status(model) in FEASIBLE_PRIMAL_STATUSES
        @warn(
            "Model$(isempty(label) ? "" : " ($label)") terminated with status $(status) " *
            "but a feasible solution is available. Results are based on this solution and " *
            "may not be optimal."
        )
        return nothing
    end

    throw(SolveFailed(status, primal_status(model), label))
end

"""
    assert_solved(bm::BendersModel; label::AbstractString = "")

Check the outcome of a Benders solve and warn if the algorithm stopped before converging.

# Notes
- The Benders algorithm stops on convergence, a CPU time limit, a maximum iteration count, 
  or a negative gap, and each of these leaves a planning solution in place. Infeasibility 
  of the underlying problem surfaces while solving the planning problem or a subproblem, 
  not here, so this method warns rather than throwing.
"""
function assert_solved(bm::BendersModel; label::AbstractString = "")
    bm.convergence === nothing && return nothing
    status = bm.convergence.termination_status
    if status != "OPTIMAL"
        @warn(
            "Benders solve$(isempty(label) ? "" : " ($label)") terminated with status " *
            "$(status) instead of OPTIMAL. Results are based on the best planning solution " *
            "found and may not be optimal."
        )
    end
    return nothing
end

"""
    solution_outcome(solution) -> NamedTuple{(:status, :termination_status)}

Summarize how a solve ended, for the run status file written by [`run_case`](@ref).

`assert_solved` throws when a solve produced nothing usable, so anything reaching this point
has a solution; the question here is whether that solution is provably optimal (`"OK"`) or
merely usable (`"SUBOPTIMAL"`, e.g. a time limit reached with a feasible incumbent, or a
Benders solve that stopped on its iteration limit). Without this distinction the status file
would report a run that ran out of time exactly like one that converged.
"""
function solution_outcome(model::Model)
    return (
        status = is_solved_and_feasible(model; allow_almost = true) ? "OK" : "SUBOPTIMAL",
        termination_status = string(termination_status(model)),
    )
end

function solution_outcome(bm::BendersModel)
    bm.convergence === nothing && return (status = "OK", termination_status = "")
    status = String(bm.convergence.termination_status)
    # A negative gap means the bounds crossed (UB < LB), and "NONE" means the loop never
    # reached a termination test.
    status in ("NEGATIVE GAP", "NONE") &&
        return (status = "SOLVE_FAILED", termination_status = status)
    return (status = status == "OPTIMAL" ? "OK" : "SUBOPTIMAL", termination_status = status)
end

solution_outcome(::Any) = (status = "OK", termination_status = "")

# A Myopic run records how each period ended as it goes; the worst period decides the
# overall status. Entries are labelled with their period number because `Restart` and
# `StopAfterPeriod` skip periods, so the nth entry is not necessarily period n.
function solution_outcome(results::MyopicResults)
    isempty(results.outcomes) && return (status = "OK", termination_status = "")

    # Worst status wins, in this order. A period whose Benders solve contradicted itself
    # must not be flattened into SUBOPTIMAL, which tells a consumer the results are usable.
    statuses = (o.status for o in results.outcomes)
    overall = if any(==("SOLVE_FAILED"), statuses)
        "SOLVE_FAILED"
    elseif all(==("OK"), statuses)
        "OK"
    else
        "SUBOPTIMAL"
    end

    return (
        status = overall,
        termination_status = join(
            ("$(o.period): $(o.termination_status)" for o in results.outcomes), ", "
        ),
    )
end

####### Entry point: dispatch on ExpansionHorizon then SolutionAlgorithm #######
function solve_case(case::Case, opt::O) where O <: Union{Optimizer, Dict{Symbol, Dict{Symbol, Any}}}
    solve_case(case, opt, expansion_horizon(case))
end

####### Perfect foresight: generate a single model + optimize! #######
function solve_case(case::Case, opt::O, ::PerfectForesight) where O <: Union{Optimizer, Dict{Symbol, Dict{Symbol, Any}}}
    alg = solution_algorithm(case)

    @info("*** Running simulation with Perfect Foresight expansion horizon and $(nameof(typeof(alg))) solution algorithm ***")

    # For Perfect Foresight, we generate a single model for the entire case (planning periods) and solve it once
    # generate_model will dispatch on the solution algorithm (e.g., Monolithic or Benders) to generate the appropriate model structure
    model = generate_model(case, opt, alg)

    optimize!(model)

    assert_solved(model)

    return (case, model)
end

####### Myopic: one model for each period, capacity carry-over, and outputs #######
function solve_case(case::Case, opt::O, ::Myopic) where O <: Union{Optimizer, Dict{Symbol, Dict{Symbol, Any}}}
    alg = solution_algorithm(case)

    @info("*** Running simulation with Myopic expansion horizon and $(nameof(typeof(alg))) solution algorithm ***")

    periods = get_periods(case)
    settings = get_settings(case)
    myopic_settings = settings.MyopicSettings
    return_results = myopic_settings[:ReturnModels]

     # Output path for writing results during iteration
    output_path = create_output_path(case.systems[1])

    # Only allocate models vector if returning models is requested
    stored = return_results ? Vector{Any}(undef, length(periods)) : nothing

    # Accumulates each period's capacity summary for the cross-period capacity_summary.csv.
    capacity_summaries = DataFrame[]

    # How each period ended, recorded here rather than read back from `stored`, which is
    # `nothing` unless `ReturnModels` is set
    period_outcomes = PeriodOutcome[]

    if myopic_settings[:Restart][:enabled]
        if myopic_settings[:Restart][:from_period] == 1
            @warn("Restarting from the first period; no previous period to load, proceeding with normal iteration.")
        else
            restart_folder = joinpath(case.systems[1].data_dirpath, myopic_settings[:Restart][:folder])
            restart_period_idx = myopic_settings[:Restart][:from_period]
            @info("Restarting myopic iteration from period $(restart_period_idx) using capacities in $(restart_folder)")
            capacity_results = Dict{Int,DataFrame}()
            for period_idx in 1:restart_period_idx-1
                capacity_results[period_idx] = load_previous_capacity_results(
                    joinpath(restart_folder, "results_period_$(period_idx)", "capacity.csv")
                )
            end
            carry_over_capacities!(periods[restart_period_idx], capacity_results, restart_period_idx-1, parameter_scaling_factor(settings))
        end
    end

    for (period_idx, system) in enumerate(periods)
        myopic_settings[:Restart][:enabled] && (period_idx < myopic_settings[:Restart][:from_period]) && continue

        if period_idx > myopic_settings[:StopAfterPeriod]
            @info("Reached specified period termination at period $(myopic_settings[:StopAfterPeriod]). Ending myopic iteration.")
            break
        end

        # generate_model will dispatch on the solution algorithm (e.g., Monolithic or Benders) to generate the appropriate model structure for this period
        model = generate_model(system, opt, settings, alg)

        optimize!(model)

        # Check model before carrying capacities forward
        assert_solved(model; label = "period $period_idx")

        outcome = solution_outcome(model)
        push!(
            period_outcomes,
            PeriodOutcome(period_idx, outcome.status, outcome.termination_status),
        )

        period_idx < length(periods) && carry_over_capacities!(periods[period_idx+1], system, perfect_foresight=false)

        push!(capacity_summaries, write_outputs(output_path, case, model, system, period_idx))

        return_results ? (stored[period_idx] = model) : (model = nothing; GC.gc())
    end

    length(capacity_summaries) > 1 && write_capacity_summary(output_path, capacity_summaries, get_output_layout(periods[1], :CapacitySummary))

    write_settings(case, joinpath(output_path, "settings.json"))

    return (case, MyopicResults(stored, output_path, period_outcomes))
end

####### optimize! for BendersModel #######
function JuMP.optimize!(bm::BendersModel)
    # call MESolvers.jl to solve the Benders decomposition problem
    raw = MacroEnergySolvers.benders(
        bm.planning_problem, bm.subproblems, bm.linking_variables_sub, Dict(pairs(bm.settings))
    )

    # update case or system with the best planning solution found by Benders
    update_with_planning_solution!(bm.update_target, raw.planning_sol.values)

    @info "Perform a final solve of the subproblems to extract the operational decisions corresponding to the best planning solution."
    bm.planning_sol = raw.planning_sol
    bm.subop_sol = MacroEnergySolvers.solve_subproblems(bm.subproblems, raw.planning_sol, true)

    bm.convergence = BendersConvergence(raw)
end

"""
    ensure_duals_available!(model::Model)

Ensure that dual values are available in the model. If the model has integer variables
and duals are not available, fixes the integer variables and re-solves the LP model to 
compute duals.

# Arguments
- `model::Model`: The JuMP model to ensure duals for

# Throws
- `ErrorException`: If the model is not solved and feasible or if the dual values are not 
available after linearization

# Notes
- This function modifies the model in-place by fixing integer and binary variables to their 
current values.
- The model is solved again in silent mode to avoid redundant output
"""
function ensure_duals_available!(model::Model)
    if has_duals(model)
        @debug "Dual values available in the model"
        return nothing
    end

    assert_is_solved_and_feasible(model)
    
    @info "Dual values not available in the model. Linearizing model and re-solving to compute duals."
    
    # Fix integer and binary variables to their current values
    fix_discrete_variables(model);
    
    # Re-solve the LP model
    optimize!(model)
    
    # Verify that duals are now available
    assert_is_solved_and_feasible(model)
    if dual_status(model) != MOI.FEASIBLE_POINT
        error("Model is not feasible after linearization.")
    end
    
    @info "Linearization successful, dual values now available."
    
    return nothing
end