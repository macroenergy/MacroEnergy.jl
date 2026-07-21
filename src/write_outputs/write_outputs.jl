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
Write results for a single Myopic iteration when using Myopic as expansion horizon and Monolithic as solution algorithm.
"""
function write_outputs(
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
Write results when using Perfect Foresight + Benders as solution algorithm.
"""
function write_outputs(
    case_path::AbstractString,
    case::Case,
    bm::BendersModel
)
    settings = get_settings(case);
    num_periods = number_of_periods(case);
    periods = get_periods(case);

    period_to_subproblem_map, _ = get_period_to_subproblem_mapping(periods)

    # Collect subproblem data (flows, NSD, storage levels, operational costs)
    @info "Collecting subproblem results..."
    scaling = parameter_scaling_factor(settings)

    subproblems_data = collect_data_from_subproblems(settings, bm.subproblems, scaling)

    # get the policy slack variables from the operational subproblems
    slack_vars = collect_distributed_policy_slack_vars(bm.subproblems)

    # get the constraint duals from the operational subproblems
    # for now, only balance constraints are exported
    balance_duals = collect_distributed_constraint_duals(bm.subproblems, BalanceConstraint)

    for (period_idx, period) in enumerate(periods)
        @info("Writing results for period $period_idx")

        ## Create results directory to store the results
        results_dir = mkpath_for_period(case_path, num_periods, period_idx)
        _write_benders_period_outputs(
            results_dir, period_idx, period, bm,
            period_to_subproblem_map[period_idx],
            subproblems_data, slack_vars, balance_duals, settings
        )
    end

    write_benders_convergence(case_path, bm.convergence)
    write_settings(case, joinpath(case_path, "settings.json"))
    return nothing
end


"""
Write results for a single period when using Myopic + Benders as solution algorithm.
LP file writing is handled here using the planning problem stored in the BendersModel.
"""
function write_outputs(
    output_path::AbstractString,
    case::Case,
    bm::BendersModel,
    system::System,
    period_idx::Int
)
    num_periods = number_of_periods(case)
    settings = get_settings(case)
    # Create results directory to store outputs for this period
    results_dir = mkpath_for_period(output_path, num_periods, period_idx)

    @info("Writing results for period $period_idx")

    if settings.MyopicSettings[:WriteModelLP]
        @info(" -- Writing LP file for period $(period_idx)")
        write_to_file(
            bm.planning_problem,
            joinpath(results_dir, "planning_problem_period_$(period_idx).lp")
        )
    end

    write_period_outputs(results_dir, period_idx, system, bm, settings)
    return nothing
end

"""
    write_period_outputs(results_dir, period_idx, system, bm, settings)

Write all outputs for a single period of a Myopic+Benders run.
"""
function write_period_outputs(
    results_dir::AbstractString,
    period_idx::Int,
    system::System,
    bm::BendersModel,
    settings::NamedTuple
)
    period_to_subproblem_map, _ = get_period_to_subproblem_mapping([system])
    subop_indices = period_to_subproblem_map[period_idx]

    scaling = parameter_scaling_factor(settings)

    subproblems_data = collect_data_from_subproblems(settings, bm.subproblems, scaling)
    slack_vars    = collect_distributed_policy_slack_vars(bm.subproblems)
    balance_duals = collect_distributed_constraint_duals(bm.subproblems, BalanceConstraint)

    _write_benders_period_outputs(
        results_dir, period_idx, system, bm,
        subop_indices, subproblems_data, slack_vars, balance_duals, settings
    )

    write_benders_convergence(results_dir, bm.convergence)
    return nothing
end


"""
    _write_benders_period_outputs(results_dir, period_idx, system, bm,
        subop_indices, subproblems_data, slack_vars,
        balance_duals, settings)

Internal helper: write all outputs for one Benders period given pre-collected subproblem
data. Called by both `write_outputs(BendersModel)` (multi-period loop) and
`write_period_outputs(BendersModel)` (Myopic+Benders single-period).
"""
function _write_benders_period_outputs(
    results_dir::AbstractString,
    period_idx::Int,
    system::System,
    bm::BendersModel,
    subop_indices,
    subproblems_data,
    slack_vars,
    balance_duals,
    settings::NamedTuple
)
    flow_df              = flows(subproblems_data)
    nsd_df               = non_served_demand(subproblems_data)
    storage_level_df     = storage_levels(subproblems_data)
    curtailment_df       = curtailment(subproblems_data)
    operational_costs_df = operational_costs(subproblems_data)

    scaling = parameter_scaling_factor(settings)

    # Note: period/system has been updated with the capacity values in planning_solution
    # at the end of function solve_case
    # Capacity results
    write_capacity(joinpath(results_dir, "capacity.csv"), system, scaling)

    # Flow results
    write_flows(joinpath(results_dir, "flows.csv"), system, flow_df[subop_indices])

    # Non-served demand results
    write_non_served_demand(joinpath(results_dir, "non_served_demand.csv"), system, nsd_df[subop_indices])

    # Storage level results
    write_storage_level(joinpath(results_dir, "storage_level.csv"), system, storage_level_df[subop_indices])
    
    # Curtailment results
    write_curtailment(joinpath(results_dir, "curtailment.csv"), system, curtailment_df[subop_indices])

    # Sub-period weights (for downstream revenue and weighted-sum calculations)
    write_time_weights(joinpath(results_dir, "time_weights.csv"), system)

    # Cost results (system level)
    costs = prepare_costs_benders(system, bm, subop_indices, settings)
    write_costs(joinpath(results_dir, "costs.csv"), system, costs, scaling)
    write_undiscounted_costs(joinpath(results_dir, "undiscounted_costs.csv"), system, costs, scaling)
    # Detailed cost breakdown (assets and zones level)
    write_detailed_costs_benders(results_dir, system, costs, operational_costs_df[subop_indices], settings, scaling)

    # Write dual values (if enabled)
    # Scaling factor to account for discounting duals in multi-period models
    var_cost_discount = compute_variable_cost_discount_scaling(period_idx, settings)
    if system.settings.DualExportsEnabled
        # Move slack variables from subproblems to planning problem
        if haskey(slack_vars, period_idx)
            populate_slack_vars_from_subproblems!(system, slack_vars[period_idx])
        else
            @debug "No slack variables found for period $period_idx"
        end
        
        # Calculate and store constraint duals from subproblems to planning problem
        if haskey(balance_duals, period_idx)
            populate_constraint_duals_from_subproblems!(system, balance_duals[period_idx], BalanceConstraint)
        else
            @debug "No balance constraint duals found for period $period_idx"
        end

        write_duals(results_dir, system, scaling, var_cost_discount)
    end

    # Full time series reconstruction (if enabled and TDR is used)
    if settings.WriteFullTimeseries
        write_full_timeseries(results_dir, system,
            flow_df[subop_indices], 
            nsd_df[subop_indices],
            storage_level_df[subop_indices], 
            curtailment_df[subop_indices],
            scaling,
            var_cost_discount)
    end

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
    scaling = parameter_scaling_factor(settings)

    # Capacity results
    write_capacity(joinpath(results_dir, "capacity.csv"), system, scaling)
    
    # Cost results (system level)
    create_discounted_cost_expressions!(model, system, settings)
    compute_undiscounted_costs!(model, system, settings)
    write_costs(joinpath(results_dir, "costs.csv"), system, model, scaling)
    write_undiscounted_costs(joinpath(results_dir, "undiscounted_costs.csv"), system, model, scaling)
    # Cost results (detailed breakdown by type and zone, discounted and undiscounted)
    write_detailed_costs(results_dir, system, model, settings, scaling)

    # Flow results
    write_flow(joinpath(results_dir, "flows.csv"), system, scaling)
    # Non-served demand results
    write_non_served_demand(joinpath(results_dir, "non_served_demand.csv"), system, scaling)
    # Storage level results
    write_storage_level(joinpath(results_dir, "storage_level.csv"), system, scaling)
    # Curtailment results
    write_curtailment(joinpath(results_dir, "curtailment.csv"), system, scaling)

    # Sub-period weights (for downstream revenue and weighted-sum calculations)
    write_time_weights(joinpath(results_dir, "time_weights.csv"), system)

    # Write dual values (if enabled)
    # Scaling factor to account for discounting duals in multi-period models
    var_cost_discount = compute_variable_cost_discount_scaling(period_idx, settings)
    if system.settings.DualExportsEnabled
        ensure_duals_available!(model)
        write_duals(results_dir, system, scaling, var_cost_discount)
    end

    # Full time series reconstruction (if enabled and TDR is used)
    if settings.WriteFullTimeseries
        write_full_timeseries(results_dir, system, scaling, var_cost_discount)
    end

    write_objective_value(results_dir, model)

    return nothing
end

"""
    write_objective_value(results_dir::AbstractString, model::Model)

Write the solver objective value to `objective_value.csv` in `results_dir`.
"""
function write_objective_value(results_dir::AbstractString, model::Model)
    file_path = joinpath(results_dir, "objective_value.csv")
    @info "Writing objective value to $file_path"
    CSV.write(file_path, DataFrame(objective_value = [JuMP.objective_value(model)]))
    return nothing
end