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
    capacity_summaries = Vector{DataFrame}(undef, num_periods)
    for (period_idx, period) in enumerate(periods)
        @info("Writing results for period $period_idx")
        results_dir = mkpath_for_period(case_path, num_periods, period_idx)
        capacity_summaries[period_idx] = write_period_outputs(results_dir, period_idx, period, model, settings)
    end
    num_periods > 1 && write_capacity_summary(case_path, capacity_summaries, periods[1])
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

    return write_period_outputs(results_dir, period_idx, system, model, settings)
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

    capacity_summaries = Vector{DataFrame}(undef, num_periods)
    for (period_idx, period) in enumerate(periods)
        @info("Writing results for period $period_idx")

        ## Create results directory to store the results
        results_dir = mkpath_for_period(case_path, num_periods, period_idx)
        capacity_summaries[period_idx] = _write_benders_period_outputs(
            results_dir, period_idx, period, bm,
            period_to_subproblem_map[period_idx],
            subproblems_data, slack_vars, balance_duals, settings
        )
    end
    num_periods > 1 && write_capacity_summary(case_path, capacity_summaries, periods[1])

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

    return write_period_outputs(results_dir, period_idx, system, bm, settings)
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

    capacity_results = _write_benders_period_outputs(
        results_dir, period_idx, system, bm,
        subop_indices, subproblems_data, slack_vars, balance_duals, settings
    )

    write_benders_convergence(results_dir, bm.convergence)
    return capacity_results
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
    # Capacity results (always collected, since the cross-period capacity summary needs them)
    capacity_results = output_enabled(system, :Capacity) ?
        write_capacity(output_file(results_dir, "capacity", system, :Capacity), system, scaling) :
        get_capacity_results(system, scaling)

    # Flow results
    output_enabled(system, :Flow) &&
        write_flows(output_file(results_dir, "flows", system, :Flow), system, flow_df[subop_indices])

    # Non-served demand results
    output_enabled(system, :NonServedDemand) &&
        write_non_served_demand(output_file(results_dir, "non_served_demand", system, :NonServedDemand), system, nsd_df[subop_indices])

    # Storage level results
    output_enabled(system, :StorageLevel) &&
        write_storage_level(output_file(results_dir, "storage_level", system, :StorageLevel), system, storage_level_df[subop_indices])

    # Curtailment results
    output_enabled(system, :Curtailment) &&
        write_curtailment(output_file(results_dir, "curtailment", system, :Curtailment), system, curtailment_df[subop_indices])

    # Sub-period weights (for downstream revenue and weighted-sum calculations)
    output_enabled(system, :TimeWeights) &&
        write_time_weights(output_file(results_dir, "time_weights", system, :TimeWeights), system)

    # Cost results (system level)
    costs = prepare_costs_benders(system, bm, subop_indices, settings)
    if output_enabled(system, :Costs)
        write_costs(output_file(results_dir, "costs", system, :Costs), system, costs, scaling)
        write_undiscounted_costs(output_file(results_dir, "undiscounted_costs", system, :Costs), system, costs, scaling)
        # Detailed cost breakdown (assets and zones level)
        write_detailed_costs_benders(results_dir, system, costs, operational_costs_df[subop_indices], settings, scaling)
    end
    # CAPEX results (investment cost × new capacity)
    output_enabled(system, :Capex) &&
        write_capex(output_file(results_dir, "capex", system, :Capex), system, scaling, Float64(settings.DiscountRate))

    # Write dual values (if enabled)
    # Scaling factor to account for discounting duals in multi-period models
    var_cost_discount = compute_variable_cost_discount_scaling(period_idx, settings)
    if output_enabled(system, :Duals)
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

    return capacity_results
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

    # Capacity results (always collected, since the cross-period capacity summary needs them)
    capacity_results = output_enabled(system, :Capacity) ?
        write_capacity(output_file(results_dir, "capacity", system, :Capacity), system, scaling) :
        get_capacity_results(system, scaling)

    # Cost results (system level)
    create_discounted_cost_expressions!(model, system, settings)
    compute_undiscounted_costs!(model, system, settings)
    if output_enabled(system, :Costs)
        write_costs(output_file(results_dir, "costs", system, :Costs), system, model, scaling)
        write_undiscounted_costs(output_file(results_dir, "undiscounted_costs", system, :Costs), system, model, scaling)
        # Cost results (detailed breakdown by type and zone, discounted and undiscounted)
        write_detailed_costs(results_dir, system, model, settings, scaling)
    end
    # CAPEX results (investment cost × new capacity)
    output_enabled(system, :Capex) &&
        write_capex(output_file(results_dir, "capex", system, :Capex), system, scaling, Float64(settings.DiscountRate))

    # Flow results
    output_enabled(system, :Flow) &&
        write_flow(output_file(results_dir, "flows", system, :Flow), system, scaling)
    # Non-served demand results
    output_enabled(system, :NonServedDemand) &&
        write_non_served_demand(output_file(results_dir, "non_served_demand", system, :NonServedDemand), system, scaling)
    # Storage level results
    output_enabled(system, :StorageLevel) &&
        write_storage_level(output_file(results_dir, "storage_level", system, :StorageLevel), system, scaling)
    # Curtailment results
    output_enabled(system, :Curtailment) &&
        write_curtailment(output_file(results_dir, "curtailment", system, :Curtailment), system, scaling)

    # Sub-period weights (for downstream revenue and weighted-sum calculations)
    output_enabled(system, :TimeWeights) &&
        write_time_weights(output_file(results_dir, "time_weights", system, :TimeWeights), system)

    # Write dual values (if enabled)
    # Scaling factor to account for discounting duals in multi-period models
    var_cost_discount = compute_variable_cost_discount_scaling(period_idx, settings)
    if output_enabled(system, :Duals)
        ensure_duals_available!(model)
        write_duals(results_dir, system, scaling, var_cost_discount)
    end

    # Full time series reconstruction (if enabled and TDR is used)
    if settings.WriteFullTimeseries
        write_full_timeseries(results_dir, system, scaling, var_cost_discount)
    end

    write_objective_value(results_dir, model)

    return capacity_results
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