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

        # Sub-period weights (for downstream revenue and weighted-sum calculations)
        write_time_weights(joinpath(results_dir, "time_weights.csv"), period)

        # Cost results (system level)
        costs = prepare_costs_benders(period, bd_results, subop_indices_period, settings)

        write_costs(joinpath(results_dir, "costs.csv"), period, costs)
        
        write_undiscounted_costs(joinpath(results_dir, "undiscounted_costs.csv"), period, costs)
        
        # Detailed cost breakdown (assets and zones level)
        write_detailed_costs_benders(results_dir, period, costs, operational_costs_df[subop_indices_period], settings)

        # Write dual values (if enabled)
        # Scaling factor to account for discounting duals in multi-period models
        var_cost_discount = compute_variable_cost_discount_scaling(period_idx, settings)
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
            
            write_duals(results_dir, period, var_cost_discount)
        end

        # Full time series reconstruction (if enabled and TDR is used)
        if settings.WriteFullTimeseries
            write_full_timeseries(results_dir, period,
                flow_df[subop_indices_period], 
                nsd_df[subop_indices_period],
                storage_level_df[subop_indices_period], 
                curtailment_df[subop_indices_period];
                var_cost_discount)
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

    # Sub-period weights (for downstream revenue and weighted-sum calculations)
    write_time_weights(joinpath(results_dir, "time_weights.csv"), system)

    # Write dual values (if enabled)
    # Scaling factor to account for discounting duals in multi-period models
    var_cost_discount = compute_variable_cost_discount_scaling(period_idx, settings)
    if system.settings.DualExportsEnabled
        ensure_duals_available!(model)
        write_duals(results_dir, system, var_cost_discount)
    end

    # Full time series reconstruction (if enabled and TDR is used)
    if settings.WriteFullTimeseries
        write_full_timeseries(results_dir, system; var_cost_discount)
    end

    return nothing
end

# ─────────────────────────────────────────────────────────────────────────────
# Stochastic write_outputs dispatches
# ─────────────────────────────────────────────────────────────────────────────

"""
    write_outputs(case_path, sc::StochasticCase, model::Model)

Write results for a stochastic monolithic solve:
- `results/capacity.csv`                             — shared investment capacity
- `results/scenario_{id}/flows.csv`                  — per-scenario operational flows
- `results/scenario_{id}/costs_by_type.csv`          — per-scenario cost breakdown by asset type
- `results/scenario_{id}/costs_by_zone.csv`          — per-scenario cost breakdown by zone
- `results/scenario_{id}/balance_duals.csv`          — per-scenario balance duals (if enabled)
- `results/costs.csv`                                — aggregate expected discounted costs (probability-weighted)
- `results/undiscounted_costs.csv`                   — aggregate expected undiscounted costs (probability-weighted)
- `results/scenario_costs.csv`                       — per-scenario discounted costs (DiscountedFixedCost, DiscountedVariableCost, DiscountedTotalCost)
- `results/scenario_undiscounted_costs.csv`          — per-scenario undiscounted costs (FixedCost, VariableCost, TotalCost)
- `results/settings.json`                            — case + stochastic settings
"""
function write_outputs(case_path::AbstractString, sc::StochasticCase, model::Model)
    inv_sys  = investment_system(sc)
    settings = get_settings(sc)
    results_dir = create_output_path(inv_sys, case_path)
    data_dir    = joinpath(results_dir, "results")
    mkpath(data_dir)

    write_capacity(joinpath(data_dir, "capacity.csv"), inv_sys)

    if any(s.system.settings.DualExportsEnabled for s in sc.scenarios)
        ensure_duals_available!(model)
    end

    for sc_r in sc.scenarios
        sc_dir = joinpath(data_dir, "scenario_$(sc_r.id)")
        mkpath(sc_dir)
        write_flow(joinpath(sc_dir, "flows.csv"), sc_r.system)
        write_non_served_demand(joinpath(sc_dir, "non_served_demand.csv"), sc_r.system)
        write_storage_level(joinpath(sc_dir, "storage_level.csv"), sc_r.system)
        write_curtailment(joinpath(sc_dir, "curtailment.csv"), sc_r.system)
        write_time_weights(joinpath(sc_dir, "time_weights.csv"), sc_r.system)

        # All stochastic scenarios share the same investment period (index 1).
        # Temporarily set period_index=1 so cost/dual functions use the correct period.
        _stochastic_set_period_index!(sc_r.system, 1)

        layout = get_output_layout(sc_r.system, :Costs)
        costs  = get_detailed_costs(sc_r.system, settings)
        write_cost_breakdown_files!(sc_dir, costs.discounted, layout;
            prefix="costs", validate_model=nothing, discounted=true)
        write_cost_breakdown_files!(sc_dir, costs.undiscounted, layout;
            prefix="undiscounted_costs", validate_model=nothing, discounted=false)

        if sc_r.system.settings.DualExportsEnabled
            write_duals(sc_dir, sc_r.system, 1.0)
        end

        _stochastic_set_period_index!(sc_r.system, sc_r.id)
    end

    _write_stochastic_costs(data_dir, sc, model)
    write_settings(sc, joinpath(results_dir, "settings.json"))

    return results_dir
end


"""Helper: write aggregate and per-scenario cost CSVs for a stochastic monolithic solve."""
function _write_stochastic_costs(results_dir::AbstractString, sc::StochasticCase, model::Model)
    inv_sys       = investment_system(sc)
    settings      = get_settings(sc)
    R             = model.ext[:scenario_ids]
    p             = model.ext[:scenario_probs]
    opexmult      = model.ext[:opexmult]
    period_length = first(settings.PeriodLengths)

    # Discounted: eFixedCost uses PV costs from planning_model!; eVariableCost is probability-weighted and discounted
    disc_fixed = value(model[:eFixedCost])
    disc_var   = value(model[:eVariableCost])

    # Undiscounted fixed: undo PV discounting on assets, recompute with face-value costs
    undo_discount_fixed_costs!(inv_sys, settings)
    unregister(model, :eFixedCost)
    unregister(model, :eOMFixedCost)
    unregister(model, :eInvestmentFixedCost)
    model[:eFixedCost]           = AffExpr(0.0)
    model[:eOMFixedCost]         = AffExpr(0.0)
    model[:eInvestmentFixedCost] = AffExpr(0.0)
    compute_fixed_costs!(inv_sys, model, :CF)
    model[:eFixedCost] = model[:eInvestmentFixedCost] + model[:eOMFixedCost]
    undisc_fixed = value(model[:eFixedCost])

    # Undiscounted variable: remove opexmult discounting, multiply by period length
    undisc_var = period_length / opexmult * disc_var

    aggregate_costs = (
        eDiscountedFixedCost    = disc_fixed,
        eDiscountedVariableCost = disc_var,
        eFixedCost              = undisc_fixed,
        eVariableCost           = undisc_var,
    )
    write_costs(joinpath(results_dir, "costs.csv"), inv_sys, aggregate_costs)
    write_undiscounted_costs(joinpath(results_dir, "undiscounted_costs.csv"), inv_sys, aggregate_costs)

    # Per-scenario costs: fixed cost is shared; variable cost differs per scenario
    sc_disc_rows = map(R) do r
        disc_var_r = opexmult * value(model[:eRawVariableCostByScenario][r])
        (scenario_id           = r,
         probability           = p[r],
         DiscountedFixedCost   = disc_fixed,
         DiscountedVariableCost = disc_var_r,
         DiscountedTotalCost   = disc_fixed + disc_var_r)
    end
    write_dataframe(joinpath(results_dir, "scenario_costs.csv"), DataFrame(sc_disc_rows))

    sc_undisc_rows = map(R) do r
        disc_var_r   = opexmult * value(model[:eRawVariableCostByScenario][r])
        undisc_var_r = period_length / opexmult * disc_var_r
        (scenario_id = r,
         probability = p[r],
         FixedCost   = undisc_fixed,
         VariableCost = undisc_var_r,
         TotalCost   = undisc_fixed + undisc_var_r)
    end
    write_dataframe(joinpath(results_dir, "scenario_undiscounted_costs.csv"), DataFrame(sc_undisc_rows))

    return nothing
end

# ─────────────────────────────────────────────────────────────────────────────
# Stochastic write helpers
# ─────────────────────────────────────────────────────────────────────────────

"""Set period_index on every TimeData entry in system.

Used before stochastic cost/dual calculations so that period-indexed discounting
functions always see period 1 (all stochastic scenarios share one investment period).
"""
function _stochastic_set_period_index!(system::System, pid::Int)
    for (_, td) in system.time_data
        td.period_index = pid
    end
end