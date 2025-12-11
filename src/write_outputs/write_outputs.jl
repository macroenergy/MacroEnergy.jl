"""
Write results when using Monolithic as solution algorithm.
"""
function write_outputs(case_path::AbstractString, case::Case, model::Model)
    num_periods = number_of_periods(case)
    periods = get_periods(case)
    for (period_idx,period) in enumerate(periods)
        @info("Writing results for period $period_idx")
        
        create_discounted_cost_expressions!(model, period, get_settings(case))

        compute_undiscounted_costs!(model, period, get_settings(case))

        ## Create results directory to store the results
        if num_periods > 1
            # Create a directory for each period
            results_dir = joinpath(case_path, "results_period_$period_idx")
        else
            # Create a directory for the single period
            results_dir = joinpath(case_path, "results")
        end
        mkpath(results_dir)

        # Scaling factor for variable cost portion of objective function
        discount_scaling = compute_variable_cost_discount_scaling(period_idx, get_settings(case))

        write_outputs(results_dir, period, model, discount_scaling)
    end
    write_settings(case, joinpath(case_path, "settings.json"))
    return nothing
end

"""
Write results when using Myopic as solution algorithm. 
"""
function write_outputs(case_path::AbstractString, case::Case, myopic_results::MyopicResults)
    @debug("Outputs were already written during iteration.")
    return nothing
end

"""
Write results when using Benders as solution algorithm.
"""
function write_outputs(case_path::AbstractString, case::Case, bd_results::BendersResults)

    settings = get_settings(case);
    num_periods = number_of_periods(case);
    periods = get_periods(case);

    period_to_subproblem_map, _ = get_period_to_subproblem_mapping(periods)

    # get the flow results from the operational subproblems
    flow_df = collect_flow_results(case, bd_results)
    
    # get the policy slack variables from the operational subproblems
    slack_vars = collect_distributed_policy_slack_vars(bd_results)

    # get the constraint duals from the operational subproblems
    # for now, only balance constraints are exported
    balance_duals = collect_distributed_constraint_duals(bd_results, BalanceConstraint)

    for (period_idx, period) in enumerate(periods)
        @info("Writing results for period $period_idx")
        ## Create results directory to store the results
        if num_periods > 1
            # Create a directory for each period
            results_dir = joinpath(case_path, "results_period_$period_idx")
        else
            # Create a directory for the single period
            results_dir = joinpath(case_path, "results")
        end
        mkpath(results_dir)

        # subproblem indices for the current period
        subop_indices_period = period_to_subproblem_map[period_idx]

        # Note: period has been updated with the capacity values in planning_solution at the end of function solve_case
        # Capacity results
        write_capacity(joinpath(results_dir, "capacity.csv"), period)

        # Flow results
        write_flows(joinpath(results_dir, "flows.csv"), period, flow_df[subop_indices_period])
        
        # Cost results
        costs = prepare_costs_benders(period, bd_results, subop_indices_period, settings)
        write_costs(joinpath(results_dir, "costs.csv"), period, costs)
        write_undiscounted_costs(joinpath(results_dir, "undiscounted_costs.csv"), period, costs)

        # Write dual values (if enabled)
        if period.settings.DualExportsEnabled
            # Move slack variables from subproblems to planning problem
            if haskey(slack_vars, period_idx)
                populate_slack_vars_from_subproblems!(period, slack_vars[period_idx])
            else
                @debug "No slack variables found for period $period_idx"
            end
            
            # Calculate and store constraint duals from subproblems to planning problem
            if haskey(balance_duals, period_idx)
                populate_constraint_duals_from_subproblems!(period, balance_duals[period_idx], BalanceConstraint)
            else
                @debug "No balance constraint duals found for period $period_idx"
            end
            
            # Scaling factor to account for discounting in multi-period models
            discount_scaling = compute_variable_cost_discount_scaling(period_idx, settings)
            write_duals_benders(results_dir, period, discount_scaling)
        end
    end
    write_settings(case, joinpath(case_path, "settings.json"))
    return nothing
end

"""
    Fallback function to write outputs for a single period.
"""
function write_outputs(results_dir::AbstractString, 
    system::System, 
    model::Model, 
    scaling::Float64=1.0
)
    
    # Capacity results
    write_capacity(joinpath(results_dir, "capacity.csv"), system)
    
    # Cost results
    write_costs(joinpath(results_dir, "costs.csv"), system, model)
    write_undiscounted_costs(joinpath(results_dir, "undiscounted_costs.csv"), system, model)

    # Flow results
    write_flow(joinpath(results_dir, "flows.csv"), system)

    # Write dual values (if enabled)
    if system.settings.DualExportsEnabled
        ensure_duals_available!(model)        
        write_duals(results_dir, system, scaling)
    end

    return nothing
end