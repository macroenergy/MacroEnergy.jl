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

        period_idx < length(periods) && carry_over_capacities!(periods[period_idx+1], system, perfect_foresight=false)

        write_outputs(output_path, case, model, system, period_idx)

        return_results ? (stored[period_idx] = model) : (model = nothing; GC.gc())
    end

    write_settings(case, joinpath(output_path, "settings.json"))

    return (case, MyopicResults(stored,output_path))
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