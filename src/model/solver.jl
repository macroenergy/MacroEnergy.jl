function solve_case(case::Case, opt::O) where O <: Union{Optimizer, Dict{Symbol, Dict{Symbol, Any}}}
    solve_case(case, opt, solution_algorithm(case))
end

function solve_case(case::Case, opt::Optimizer, ::Monolithic)

    @info("*** Running simulation with monolithic solver ***")

    model = generate_model(case, opt)

    # For monolithic solution there is only one model
    # scale constraints if the flag is true in the first system
    if case.systems[1].settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(model)
    end

    optimize!(model)

    return (case, model)
end

####### myopic expansion #######
function solve_case(case::Case, opt::Optimizer, ::Myopic)

    @info("*** Running simulation with myopic iteration ***")
    
    myopic_results = run_myopic_iteration!(case,opt)

    return (case, myopic_results)
end

####### Benders decomposition algorithm #######
function solve_case(case::Case, opt::Dict{Symbol, Dict{Symbol, Any}}, ::Benders)

    @info("*** Running simulation with Benders decomposition ***")
    bd_setup = get_settings(case).BendersSettings
    periods = get_periods(case);

    # Decomposed system
    periods_decomp = generate_decomposed_system(periods);

    planning_problem = initialize_planning_problem!(case,opt[:planning])

    subproblems, linking_variables_sub = initialize_subproblems!(periods_decomp, opt[:subproblems], get_settings(case), bd_setup[:Distributed],bd_setup[:IncludeSubproblemSlacksAutomatically])

    results = MacroEnergySolvers.benders(planning_problem, subproblems, linking_variables_sub, Dict(pairs(bd_setup)))

    update_with_planning_solution!(case, results.planning_sol.values)

    @info "Perform a final solve of the subproblems to extract the operational decisions corresponding to the best planning solution."

    update_with_subproblem_solutions!(subproblems, results)

    return (case, BendersResults(results, subproblems))
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