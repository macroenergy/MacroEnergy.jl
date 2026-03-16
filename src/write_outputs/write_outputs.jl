"""
Write results when using Monolithic as solution algorithm.
"""
function write_outputs(
    case_path::AbstractString, 
    case::Case, 
    model::Model
)
    num_periods = number_of_periods(case)
    periods = get_periods(case)
    settings = get_settings(case)
    for (period_idx, period) in enumerate(periods)
        @info("Writing results for period $period_idx")
        results_dir = mkpath_for_period(case_path, num_periods, period_idx)
        write_period_outputs(results_dir, period_idx, period, model, settings)
    end
    write_settings(case, joinpath(case_path, "settings.json"))
    return nothing
end

"""
Write results when using Myopic as solution algorithm.
"""
function write_outputs_myopic(
    output_path::AbstractString, 
    case::Case, 
    model::Model, 
    system::System, 
    period_idx::Int
)
    num_periods = number_of_periods(case)
    settings = get_settings(case)
    # Create results directory to store outputs for this period
    results_dir = mkpath_for_period(output_path, num_periods, period_idx)

    if settings.MyopicSettings[:WriteModelLP]
        @info(" -- Writing LP file for period $(period_idx)")
        write_to_file(model, joinpath(results_dir, "model_period_$(period_idx).lp"))
    end

    write_period_outputs(results_dir, period_idx, system, model, settings)
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

    # Collect subproblem data (flows, NSD, storage levels, operational costs)
    @info "Collecting subproblem results..."
    subproblems_data = collect_data_from_subproblems(case, bd_results)
    
    # Extract individual result types from the unified extraction
    flow_df = flows(subproblems_data)
    nsd_df = non_served_demand(subproblems_data)
    storage_level_df = storage_levels(subproblems_data)
    curtailment_df = curtailment(subproblems_data)
    operational_costs_df = operational_costs(subproblems_data)
    
    # get the policy slack variables from the operational subproblems
    slack_vars = collect_distributed_policy_slack_vars(bd_results)

    # get the constraint duals from the operational subproblems
    # for now, only balance constraints are exported
    balance_duals = collect_distributed_constraint_duals(bd_results, BalanceConstraint)

    for (period_idx, period) in enumerate(periods)
        @info("Writing results for period $period_idx")

        ## Create results directory to store the results
        results_dir = mkpath_for_period(case_path, num_periods, period_idx)

        # subproblem indices for the current period
        subop_indices_period = period_to_subproblem_map[period_idx]

        # Note: period has been updated with the capacity values in planning_solution at the end of function solve_case
        # Capacity results
        write_capacity(joinpath(results_dir, "capacity.csv"), period)

        # Flow results
        write_flows(joinpath(results_dir, "flows.csv"), period, flow_df[subop_indices_period])

        # Non-served demand results
        write_non_served_demand(joinpath(results_dir, "non_served_demand.csv"), period, nsd_df[subop_indices_period])

        # Storage level results
        write_storage_level(joinpath(results_dir, "storage_level.csv"), period, storage_level_df[subop_indices_period])
        
        # Curtailment results
        write_curtailment(joinpath(results_dir, "curtailment.csv"), period, curtailment_df[subop_indices_period])
        
        # Cost results (system level)
        costs = prepare_costs_benders(period, bd_results, subop_indices_period, settings)

        write_costs(joinpath(results_dir, "costs.csv"), period, costs)
        
        write_undiscounted_costs(joinpath(results_dir, "undiscounted_costs.csv"), period, costs)
        
        # Detailed cost breakdown (assets and zones level)
        write_detailed_costs_benders(results_dir, period, costs, operational_costs_df[subop_indices_period], settings)

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
            write_duals(results_dir, period, discount_scaling)
        end
    end
    	
    write_benders_convergence(case_path, bd_results)

    write_settings(case, joinpath(case_path, "settings.json"))
    return nothing
end

"""
    write_period_outputs(results_dir, period_idx, system, model, settings)

Write all outputs for a single period (one iteration of the Monolithic/Myopic loop).
Sets up cost expressions, then writes capacity, costs, flows, NSD, storage, and duals.
Used by Monolithic in its loop and by Myopic after setup.
"""
function write_period_outputs(
    results_dir::AbstractString,
    period_idx::Int,
    system::System,
    model::Model,
    settings::NamedTuple
)
    
    # Capacity results
    write_capacity(joinpath(results_dir, "capacity.csv"), system)
    
    # Cost results (system level)
    create_discounted_cost_expressions!(model, system, settings)
    compute_undiscounted_costs!(model, system, settings)
    write_costs(joinpath(results_dir, "costs.csv"), system, model)
    write_undiscounted_costs(joinpath(results_dir, "undiscounted_costs.csv"), system, model)
    # Cost results (detailed breakdown by type and zone, discounted and undiscounted)
    write_detailed_costs(results_dir, system, model, settings)

    # Flow results
    write_flow(joinpath(results_dir, "flows.csv"), system)
    # Non-served demand results
    write_non_served_demand(joinpath(results_dir, "non_served_demand.csv"), system)
    # Storage level results
    write_storage_level(joinpath(results_dir, "storage_level.csv"), system)
    # Curtailment results
    write_curtailment(joinpath(results_dir, "curtailment.csv"), system)

    # Write dual values (if enabled)
    if system.settings.DualExportsEnabled
        ensure_duals_available!(model)
        # Scaling factor for variable cost portion of objective function
        discount_scaling = compute_variable_cost_discount_scaling(period_idx, settings)
        write_duals(results_dir, system, discount_scaling)
    end

    return nothing
end