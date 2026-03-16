"""
Cost outputs - everything related to cost data extraction and output.
"""

## Write cost outputs ##
# This is the main function to write the cost outputs to a file.
"""
    write_costs(
        file_path::AbstractString, 
        system::System, 
        model::Union{Model,NamedTuple}; 
        scaling::Float64=1.0, 
        drop_cols::Vector{AbstractString}=String[]
    )

Write the optimal cost results for all assets/edges in a system to a file. 
The extension of the file determines the format of the file.

# Arguments
- `file_path::AbstractString`: The path to the file where the results will be written
- `system::System`: The system containing the assets/edges to analyze as well as the settings for the output
- `model::Union{Model,NamedTuple}`: The optimal model after the optimization
- `scaling::Float64`: The scaling factor for the results
- `drop_cols::Vector{AbstractString}`: Columns to drop from the DataFrame

# Returns
- `nothing`: The function returns nothing, but writes the results to the file
"""
function write_costs(
    file_path::AbstractString, 
    system::System, 
    model::Union{Model,NamedTuple};
    scaling::Float64=1.0, 
    drop_cols::Vector{<:AbstractString}=String[]
)
    @info "Writing total discounted costs to $file_path"

    # Get costs and determine layout (wide or long)
    costs = get_optimal_discounted_costs(model; scaling)
    layout = get_output_layout(system, :Costs)

    if layout == "wide"
        default_drop_cols = ["case_name", "year", "commodity", "zone", "resource_id", "component_id", "type"]
        # Only use default_drop_cols if user didn't specify any
        drop_cols = isempty(drop_cols) ? default_drop_cols : drop_cols
        costs = reshape_wide(costs)
    end

    write_dataframe(file_path, costs, drop_cols)
    return nothing
end

"""
    write_undiscounted_costs(
        file_path::AbstractString,
        system::System,
        model::Union{Model,NamedTuple};
        scaling::Float64=1.0,
        drop_cols::Vector{AbstractString}=String[]
    )

Write the optimal undiscounted cost results (fixed, variable, total) to a file.
The extension of the file determines the format (CSV, Parquet, etc.).

# Arguments
- `file_path::AbstractString`: Path to the output file
- `system::System`: The system (for output layout settings)
- `model::Union{Model,NamedTuple}`: The optimized model
- `scaling::Float64`: Scaling factor for the results
- `drop_cols::Vector{AbstractString}`: Columns to drop from the DataFrame
"""
function write_undiscounted_costs(
    file_path::AbstractString, 
    system::System, 
    model::Union{Model,NamedTuple};
    scaling::Float64=1.0, 
    drop_cols::Vector{<:AbstractString}=String[]
)
    @info "Writing total undiscounted costs to $file_path"

    # Get costs and determine layout (wide or long)
    costs = get_optimal_undiscounted_costs(model; scaling)
    layout = get_output_layout(system, :Costs)

    if layout == "wide"
        default_drop_cols = ["case_name", "year", "commodity", "zone", "resource_id", "component_id", "type"]
        # Only use default_drop_cols if user didn't specify any
        drop_cols = isempty(drop_cols) ? default_drop_cols : drop_cols
        costs = reshape_wide(costs)
    end

    write_dataframe(file_path, costs, drop_cols)
    return nothing
end

## Cost extraction functions ##
"""
    get_optimal_discounted_costs(model::Union{Model,NamedTuple}; scaling::Float64=1.0)

Extract total discounted costs (fixed, variable, total) from the optimization results and return them as a DataFrame.
"""
function get_optimal_discounted_costs(model::Union{Model,NamedTuple}; scaling::Float64=1.0)
    @debug " -- Getting optimal discounted costs for the system."
    costs = prepare_discounted_costs(model, scaling)
    costs[!, (!isa).(eachcol(costs), Vector{Missing})] # remove missing columns
end

"""
    get_optimal_undiscounted_costs(model::Union{Model,NamedTuple}; scaling::Float64=1.0)

Extract total undiscounted costs (fixed, variable, total) from the optimization results and return them as a DataFrame.
"""
function get_optimal_undiscounted_costs(model::Union{Model,NamedTuple}; scaling::Float64=1.0)
    @debug " -- Getting optimal discounted costs for the system."
    costs = prepare_undiscounted_costs(model, scaling)
    costs[!, (!isa).(eachcol(costs), Vector{Missing})] # remove missing columns
end

# The following functions will return:
# - Variable cost
# - Fixed cost
# - Total cost
function prepare_undiscounted_costs(model::Union{Model,NamedTuple}, scaling::Float64=1.0)
    fixed_cost = value(model[:eFixedCost])
    variable_cost = value(model[:eVariableCost])
    total_cost = fixed_cost + variable_cost
    return DataFrame(
        case_name = fill(:missing, 3),
        commodity = fill(:all, 3),
        zone = fill(:all, 3),
        resource_id = fill(:all, 3),
        component_id = fill(:all, 3),
        type = fill(:Cost, 3),
        variable = [:FixedCost, :VariableCost, :TotalCost],
        year = fill(:missing, 3),
        value = [fixed_cost, variable_cost, total_cost] .* scaling^2
    )
end

function prepare_discounted_costs(model::Union{Model,NamedTuple}, scaling::Float64=1.0)
    fixed_cost = value(model[:eDiscountedFixedCost])
    variable_cost = value(model[:eDiscountedVariableCost])
    total_cost = fixed_cost + variable_cost
    return DataFrame(
        case_name = fill(:missing, 3),
        commodity = fill(:all, 3),
        zone = fill(:all, 3),
        resource_id = fill(:all, 3),
        component_id = fill(:all, 3),
        type = fill(:Cost, 3),
        variable = [:DiscountedFixedCost, :DiscountedVariableCost, :DiscountedTotalCost],
        year = fill(:missing, 3),
        value = [fixed_cost, variable_cost, total_cost] .* scaling^2
    )
end

function compute_fixed_costs!(system::System, model::Model, cost_type::Symbol=:PV)
    for a in system.assets
        compute_fixed_costs!(a, model, cost_type)
    end
end

function compute_fixed_costs!(a::AbstractAsset, model::Model, cost_type::Symbol=:PV)
    for t in fieldnames(typeof(a))
        compute_fixed_costs!(getfield(a, t), model, cost_type)
    end
end

function compute_fixed_costs!(g::Union{Node,Transformation},model::Model, cost_type::Symbol=:PV)
    return nothing
end

function compute_investment_costs!(system::System, model::Model, cost_type::Function=pv_period_investment_cost)
    for a in system.assets
        compute_investment_costs!(a, model, cost_type)
    end
end

function compute_investment_costs!(a::AbstractAsset, model::Model, cost_type::Function=pv_period_investment_cost)
    for t in fieldnames(typeof(a))
        compute_investment_costs!(getfield(a, t), model, cost_type)
    end
end

function compute_investment_costs!(g::Union{Node,Transformation}, model::Model, cost_type::Function=pv_period_investment_cost)
    return nothing
end

"""
    compute_investment_cost(o::T) where T <: Union{AbstractEdge, AbstractStorage}

Returns `(pv, cf)::NTuple{2,Float64}`: investment cost discounted to period start (PV) and 
undiscounted total cash flow (CF) for an edge or storage (computed as `cost * new_capacity`).
"""
function compute_investment_cost(o::T)::NTuple{2,Float64} where T <: Union{AbstractEdge, AbstractStorage}
    (has_capacity(o) && can_expand(o)) || return (0.0, 0.0)
    pv = pv_period_investment_cost(o)
    isnothing(pv) && error("pv_period_investment_cost is not set for $(id(o)); call discount_fixed_costs! before writing costs")
    cf = cf_period_investment_cost(o)
    isnothing(cf) && error("cf_period_investment_cost is not set for $(id(o)); call undo_discount_fixed_costs! before writing costs")
    cap = value(new_capacity(o))
    return (pv * cap, cf * cap)
end

"""
    compute_fixed_om_cost(o::T) where T <: Union{AbstractEdge, AbstractStorage}

Returns `(pv, cf)::NTuple{2,Float64}`: fixed O&M cost discounted to period start (PV) and undiscounted
total cash flow (CF) for an edge or storage (computed as `cost * capacity`).
"""
function compute_fixed_om_cost(o::T)::NTuple{2,Float64} where T <: Union{AbstractEdge, AbstractStorage}
    (has_capacity(o) && fixed_om_cost(o) > 0) || return (0.0, 0.0)
    pv = pv_period_fixed_om_cost(o)
    isnothing(pv) && error("pv_period_fixed_om_cost is not set for $(id(o)); call discount_fixed_costs! before writing costs")
    cf = cf_period_fixed_om_cost(o)
    isnothing(cf) && error("cf_period_fixed_om_cost is not set for $(id(o)); call undo_discount_fixed_costs! before writing costs")
    cap = value(capacity(o))
    return (pv * cap, cf * cap)
end

@doc raw"""
    compute_variable_om_cost(o::T) where T <: Union{AbstractEdge, AbstractStorage}

Compute variable O&M cost for an edge: sum over time of `subperiod_weight * variable_om_cost * flow`.
Returns a Float64 value.
"""
function compute_variable_om_cost(e::AbstractEdge)::Float64
    variable_om_cost(e) <= 0 && return 0.0
    vom_cost = 0.0
    for t in time_interval(e)
        w = current_subperiod(e, t)
        vom_cost += subperiod_weight(e, w) * variable_om_cost(e) * value(flow(e, t))
    end
    return vom_cost
end

@doc raw"""
    compute_fuel_cost(e::AbstractEdge)

Compute fuel cost for an edge: sum over time of `subperiod_weight * price(start_vertex) * flow`.
Only applicable to edges with a start node.
Returns a Float64 value.
"""
function compute_fuel_cost(e::AbstractEdge)::Float64
    (!isa(start_vertex(e), Node) || isempty(price(start_vertex(e)))) && return 0.0
    fuel_cost = 0.0
    for t in time_interval(e)
        w = current_subperiod(e, t)
        fuel_cost += subperiod_weight(e, w) * price(start_vertex(e), t) * value(flow(e, t))
    end
    return fuel_cost
end

"""
    compute_startup_cost(e::EdgeWithUC)

Compute startup cost for an edge.
Only applicable to edges with unit commitment constraints (EdgeWithUC).
Returns a Float64 value.
"""
function compute_startup_cost(e::EdgeWithUC)::Float64
    startup_cost(e) <= 0 && return 0.0
    startup_cost_val = 0.0
    for t in time_interval(e)
        w = current_subperiod(e, t)
        startup_cost_val += subperiod_weight(e, w) * startup_cost(e) * capacity_size(e) * value(ustart(e, t))
    end
    return startup_cost_val
end
compute_startup_cost(e::AbstractEdge)::Float64 = 0.0

@doc raw"""
    compute_nsd_cost(n::Node)

Compute non-served demand (NSD) cost for a node: sum over time of `subperiod_weight * price_non_served_demand * non_served_demand`.
Only applicable to nodes with non-served demand constraints.
Returns a Float64 value.
"""
function compute_nsd_cost(n::Node)::Float64
    if isempty(non_served_demand(n))
        return 0.0
    end
    
    nsd_cost = 0.0
    for t in time_interval(n)
        w = current_subperiod(n, t)
        for s in segments_non_served_demand(n)
            nsd_cost += subperiod_weight(n, w) * price_non_served_demand(n, s) * value(non_served_demand(n, s, t))
        end
    end
    return nsd_cost
end

@doc raw"""
    compute_supply_cost(n::Node)

Compute supply cost for a node: sum over time of `subperiod_weight * price_supply * supply_flow`.
Only applicable to nodes with non-zero `max_supply`.
Returns a Float64 value.
"""
function compute_supply_cost(n::Node)::Float64
    if all(iszero, max_supply(n))
        return 0.0
    end
    supply_cost = 0.0
    for t in time_interval(n)
        w = current_subperiod(n, t)
        for s in supply_segments(n)
            supply_cost += subperiod_weight(n, w) * price_supply(n, s) * value(supply_flow(n, s, t))
        end
    end
    return supply_cost
end

@doc raw"""
    compute_slack_cost(n::Node)

Compute unmet policy (slack) cost for a node: sum over time of `subperiod_weight * price_unmet_policy * policy_slack_vars`.
Only applicable to nodes with policy constraints.
Returns a Float64 value.
"""
function compute_slack_cost(n::Node)::Float64
    slack_cost = 0.0
    
    for (ct_type, penalty_price) in price_unmet_policy(n)
        slack_var_key = Symbol(string(ct_type) * "_Slack")
        if haskey(policy_slack_vars(n), slack_var_key)
            slack_vars = policy_slack_vars(n)[slack_var_key]
            for w in subperiod_indices(n)
                slack_cost += subperiod_weight(n, w) * penalty_price * value(slack_vars[w])
            end
        end
    end
    
    return slack_cost
end

function create_discounted_cost_expressions!(model::Model, system::System, settings::NamedTuple)
    
    period_index = system.time_data[:Electricity].period_index;
    discount_rate = settings.DiscountRate
    period_lengths = collect(settings.PeriodLengths)
    period_start_year = total_years(period_lengths[1:period_index-1])
    discount_factor = present_value_factor(discount_rate, period_start_year)
    
    unregister(model,:eDiscountedFixedCost)

    if isa(solution_algorithm(settings[:SolutionAlgorithm]), Myopic)

        unregister(model,:eDiscountedInvestmentFixedCost)
        add_costs_not_seen_by_myopic!(system, settings)
        unregister(model,:eInvestmentFixedCost)
        model[:eInvestmentFixedCost] = AffExpr(0.0)
        compute_investment_costs!(system, model, pv_period_investment_cost)
        
        model[:eDiscountedInvestmentFixedCost] = discount_factor * model[:eInvestmentFixedCost]
        
        model[:eDiscountedFixedCost] = model[:eDiscountedInvestmentFixedCost] + model[:eOMFixedCostByPeriod][period_index]

    elseif isa(solution_algorithm(settings[:SolutionAlgorithm]), Monolithic) || isa(solution_algorithm(settings[:SolutionAlgorithm]), Benders)
        # Perfect foresight  cases (applies to both Monolithic and Benders)
        model[:eDiscountedFixedCost] = model[:eFixedCostByPeriod][period_index]
    else
        nothing
    end

    if !isa(solution_algorithm(settings[:SolutionAlgorithm]), Benders)
        ### For Benders, variable costs are discounted within the subproblems
        unregister(model,:eDiscountedVariableCost)
        model[:eDiscountedVariableCost] = model[:eVariableCostByPeriod][period_index]
    end
end

function compute_undiscounted_costs!(model::Model, system::System, settings::NamedTuple)
    
    period_lengths = collect(settings.PeriodLengths)
    discount_rate = settings.DiscountRate
    period_index = system.time_data[:Electricity].period_index;

    undo_discount_fixed_costs!(system, settings)
    unregister(model,:eFixedCost)
    model[:eFixedCost] = AffExpr(0.0)
    model[:eOMFixedCost] = AffExpr(0.0)
    model[:eInvestmentFixedCost] = AffExpr(0.0)
    compute_fixed_costs!(system, model, :CF)
    model[:eFixedCost] = model[:eInvestmentFixedCost] + model[:eOMFixedCost] 

    if !isa(solution_algorithm(settings[:SolutionAlgorithm]), Benders) 
        period_start_year = total_years(period_lengths[1:period_index-1])
        discount_factor = present_value_factor(discount_rate, period_start_year)
        opexmult = present_value_annuity_factor(discount_rate, period_lengths[period_index])
        model[:eVariableCost] = period_lengths[period_index] * model[:eVariableCostByPeriod][period_index] / (discount_factor * opexmult)
    end
end

##############################
## Detailed Cost Breakdown  ##
##############################

# Cost category symbols for output
const COST_CATEGORIES = [:Investment, :FixedOM, :VariableOM, :Fuel, :Startup, :NonServedDemand, :Supply, :UnmetPolicyPenalty]

# Categories discounted with discount_factor
const FIXED_COST_CATEGORIES = Set([:Investment,:FixedOM])

# Categories only for variable operating costs (discounted with discount_factor * opexmult)
const VARIABLE_OPERATING_COST_CATEGORIES = Set([:VariableOM, :Fuel, :Startup, :NonServedDemand, :Supply, :UnmetPolicyPenalty])

@doc raw"""
    write_detailed_costs(
        results_dir::AbstractString,
        system::System,
        model::Model,
        settings::NamedTuple;
        scaling::Float64=1.0
    )

Write detailed cost breakdown files (both discounted and undiscounted):
- costs\_by\_type.csv / undiscounted\_costs\_by\_type.csv
- costs\_by\_zone.csv / undiscounted\_costs\_by\_zone.csv

Costs are computed once per discounting mode, then aggregated and written.

# Arguments
- `results_dir::AbstractString`: Directory to write output files
- `system::System`: The system containing assets
- `model::Model`: The optimized model (for objective value validation). It should contain four fields: :eDiscountedFixedCost, :eDiscountedVariableCost, :eFixedCost, :eVariableCost.
- `settings::NamedTuple`: Case settings containing DiscountRate and PeriodLengths
- `scaling::Float64=1.0`: Scaling factor
"""
function write_detailed_costs(
    results_dir::AbstractString,
    system::System,
    model::Model,
    settings::NamedTuple;
    scaling::Float64=1.0
)
    @debug "Writing detailed cost breakdown files"

    layout = get_output_layout(system, :Costs)
    costs = get_detailed_costs(system, settings; scaling)

    # Write discounted costs by type and zone
    write_cost_breakdown_files!(
        results_dir, costs.discounted, layout;
        prefix="costs",
        validate_model=model,
        discounted=true,
        scaling
    )
    # Write undiscounted costs by type and zone
    write_cost_breakdown_files!(
        results_dir, costs.undiscounted, layout;
        prefix="undiscounted_costs",
        validate_model=model,
        discounted=false,
        scaling
    )

    return nothing
end

"""
    write_detailed_costs_benders(
        results_dir::AbstractString,
        system::System,
        planning_problem_costs::NamedTuple,
        operational_costs_df::Vector{DataFrame},
        settings::NamedTuple;
        scaling::Float64=1.0
    )

Write detailed cost breakdown files for Benders decomposition for a single period.
Combines fixed costs from the planning problem with operational costs from subproblems.

# Arguments
- `results_dir::AbstractString`: Directory to write output files
- `system::System`: The system (with capacity values from planning solution)
- `benders_costs::NamedTuple`: The benders costs (for objective value validation). It should contain four fields: :eDiscountedFixedCost, :eDiscountedVariableCost, :eFixedCost, :eVariableCost.
- `operational_costs_df::Vector{DataFrame}`: Operational costs from subproblems for the current period
- `settings::NamedTuple`: Case settings
- `scaling::Float64=1.0`: Scaling factor
"""
function write_detailed_costs_benders(
    results_dir::AbstractString,
    system::System,
    benders_costs::NamedTuple,
    operational_costs_df::Vector{DataFrame},
    settings::NamedTuple;
    scaling::Float64=1.0
)
    @debug "Writing detailed cost breakdown files (Benders)"

    # Aggregate operational costs from subproblems in the current period
    period_operational_costs = aggregate_operational_costs(operational_costs_df)

    layout = get_output_layout(system, :Costs)
    costs = get_detailed_costs_benders(system, period_operational_costs, settings; scaling)

    # Write discounted costs by type and zone
    write_cost_breakdown_files!(results_dir, costs.discounted, layout; 
        prefix="costs",
        validate_model=benders_costs,
        discounted=true,
        scaling)

    # Write undiscounted costs by type and zone
    write_cost_breakdown_files!(results_dir, costs.undiscounted, layout; 
        prefix="undiscounted_costs",
        validate_model=benders_costs,
        discounted=false,
        scaling)

    return nothing
end

@doc raw"""
    write_cost_breakdown_files!(
        results_dir::AbstractString,
        detailed_costs::DataFrame,
        layout::String,
        suffix::String;
        validate_model::Union{Model,NamedTuple,Nothing}=nothing,
        discounted::Bool=false,
        scaling::Float64=1.0
    )

Helper function to write cost breakdown files (by type and by zone).
Used by both `write_detailed_costs` and `write_detailed_costs_benders`.

# Arguments
- `results_dir::AbstractString`: Directory to write output files
- `detailed_costs::DataFrame`: DataFrame with columns: zone, type, category, value
- `layout::String`: Output layout ("wide" or "long")
- `prefix::String`: Prefix for file names (e.g., "costs" or "undiscounted\_costs")
- `validate_model`: Optional model for objective value validation. It should contain four fields: :eDiscountedFixedCost, :eDiscountedVariableCost, :eFixedCost, :eVariableCost.
- `discounted::Bool`: Whether costs are discounted (for validation)
- `scaling::Float64`: Scaling factor (for validation)
"""
function write_cost_breakdown_files!(
    results_dir::AbstractString,
    detailed_costs::DataFrame,
    layout::String;
    prefix::String="costs",
    validate_model::Union{Model,NamedTuple,Nothing}=nothing,
    discounted::Bool=false,
    scaling::Float64=1.0
)
    # Write costs by type
    costs_by_type = aggregate_costs_by_type(detailed_costs)
    add_total_row!(costs_by_type, :type)
    !isnothing(validate_model) && validate_total_cost(costs_by_type, validate_model, discounted, scaling)
    layout == "wide" && (costs_by_type = reshape_costs_wide(costs_by_type, :type))
    @info "Writing detailed $(discounted ? "discounted" : "undiscounted") costs by type to $(joinpath(results_dir, "$(prefix)_by_type.csv"))"
    write_dataframe(joinpath(results_dir, "$(prefix)_by_type.csv"), costs_by_type, String[])
    
    # Write costs by zone
    costs_by_zone = aggregate_costs_by_zone(detailed_costs)
    add_total_row!(costs_by_zone, :zone)
    !isnothing(validate_model) && validate_total_cost(costs_by_zone, validate_model, discounted, scaling)
    layout == "wide" && (costs_by_zone = reshape_costs_wide(costs_by_zone, :zone))
    @info "Writing detailed $(discounted ? "discounted" : "undiscounted") costs by zone to $(joinpath(results_dir, "$(prefix)_by_zone.csv"))"
    write_dataframe(joinpath(results_dir, "$(prefix)_by_zone.csv"), costs_by_zone, String[])
    
    return nothing
end

"""
    get_detailed_costs(system::System, settings::NamedTuple; scaling::Float64=1.0)

Collect all detailed costs from the system, returning both discounted and undiscounted DataFrames.
Uses period cost attributes (for edges and storages) and economics.jl for discount factors.

Returns a NamedTuple `(discounted=df_discounted, undiscounted=df_undiscounted)` with the two 
DataFrames having columns: zone, type, category, value.
"""
function get_detailed_costs(system::System, settings::NamedTuple; scaling::Float64=1.0)
    # Ensure cf_period_* attributes are available for undiscounted cost calculations
    undo_discount_fixed_costs!(system, settings)

    zones = String[]
    types = String[]
    categories = Symbol[]
    values_discounted = Float64[]
    values_undiscounted = Float64[]

    edges, edge_asset_map = get_edges(system, return_ids_map=true)
    storages, storage_asset_map = get_storages(system, return_ids_map=true)

    # Collect edge costs (Investment/FixedOM are both discounted and undiscounted at period start; VariableOM/Fuel/Startup will be discounted later)
    for e in edges
        inv_pv, inv_cf = compute_investment_cost(e)
        fom_pv, fom_cf = compute_fixed_om_cost(e)
        vom = compute_variable_om_cost(e)
        fuel = compute_fuel_cost(e)
        startup = compute_startup_cost(e)

        (inv_pv == 0 && inv_cf == 0 && fom_pv == 0 && fom_cf == 0 && vom == 0 && fuel == 0 && startup == 0) && continue

        zone = get_zone_name(e)
        asset_type = get_type(edge_asset_map[id(e)])

        for (category, cost_pv, cost_cf) in [
            (:Investment, inv_pv, inv_cf),
            (:FixedOM, fom_pv, fom_cf),
            (:VariableOM, vom, vom), # first term is discounted later (vectorized)
            (:Fuel, fuel, fuel), # first term is discounted later (vectorized)
            (:Startup, startup, startup), # first term is discounted later (vectorized)
        ]
            (cost_pv == 0 && cost_cf == 0) && continue
            push!(zones, zone)
            push!(types, asset_type)
            push!(categories, category)
            push!(values_discounted, cost_pv)
            push!(values_undiscounted, cost_cf)
        end
    end

    # Collect storage costs (Investment/FixedOM are both discounted and undiscounted at period start)
    for g in storages
        inv_pv, inv_cf = compute_investment_cost(g)
        fom_pv, fom_cf = compute_fixed_om_cost(g)

        (inv_pv == 0 && inv_cf == 0 && fom_pv == 0 && fom_cf == 0) && continue

        zone = get_zone_name(g)
        asset_type = get_type(storage_asset_map[id(g)])

        for (category, cost_pv, cost_cf) in [
            (:Investment, inv_pv, inv_cf),
            (:FixedOM, fom_pv, fom_cf),
        ]
            (cost_pv == 0 && cost_cf == 0) && continue
            push!(zones, zone)
            push!(types, asset_type)
            push!(categories, category)
            push!(values_discounted, cost_pv)
            push!(values_undiscounted, cost_cf)
        end
    end

    # Collect node costs (NonServedDemand/Supply/UnmetPolicyPenalty will be discounted later)
    for loc in system.locations
        isa(loc, Node) || continue

        zone = get_zone_name(loc)
        asset_type = get_type(loc)

        nsd_cost = compute_nsd_cost(loc)
        if nsd_cost > 0
            push!(zones, zone)
            push!(types, asset_type)
            push!(categories, :NonServedDemand)
            push!(values_discounted, nsd_cost)
            push!(values_undiscounted, nsd_cost)
        end

        supply_cost = compute_supply_cost(loc)
        if supply_cost > 0
            push!(zones, zone)
            push!(types, asset_type)
            push!(categories, :Supply)
            push!(values_discounted, supply_cost)
            push!(values_undiscounted, supply_cost)
        end

        slack_cost = compute_slack_cost(loc)
        if slack_cost > 0
            push!(zones, zone)
            push!(types, asset_type)
            push!(categories, :UnmetPolicyPenalty)
            push!(values_discounted, slack_cost)
            push!(values_undiscounted, slack_cost)
        end
    end

    # Apply discounting
    period_index = system.time_data[:Electricity].period_index
    discount_rate = settings.DiscountRate
    period_lengths = settings.PeriodLengths
    period_length = period_lengths[period_index]
    period_start_year = total_years(period_lengths[1:period_index-1])
    discount_factor = present_value_factor(discount_rate, period_start_year)
    opexmult = present_value_annuity_factor(discount_rate, period_lengths[period_index])

    is_fixed_cost = [category in FIXED_COST_CATEGORIES for category in categories]
    is_variable_cost = [category in VARIABLE_OPERATING_COST_CATEGORIES for category in categories]

    # Discounted: Investment/FixedOM values already hold pv_period_* * capacity (PV at period start),
    # so only discount_factor is needed to bring them to case start.
    # Variable costs are raw sums; they get the full opex multiplier.
    @views values_discounted[is_fixed_cost] .*= discount_factor
    @views values_discounted[is_variable_cost] .*= discount_factor * opexmult

    # Undiscounted: Variable * period_length (Investment/FixedOM already in CF terms via cf_period_*)
    @views values_undiscounted[is_variable_cost] .*= period_length

    # Scaling
    if scaling != 1.0
        values_discounted .*= scaling^2
        values_undiscounted .*= scaling^2
    end

    return (
        discounted = DataFrame(zone=zones, type=types, category=categories, value=values_discounted),
        undiscounted = DataFrame(zone=zones, type=types, category=categories, value=values_undiscounted)
    )
end

"""
    get_detailed_costs_benders(
        system::System,
        operational_costs::DataFrame,
        settings::NamedTuple;
        scaling::Float64=1.0
    )

Combine fixed costs from the planning problem with operational costs from subproblems.
Returns a NamedTuple `(discounted=df_discounted, undiscounted=df_undiscounted)` with the two 
DataFrames having columns: zone, type, category, value.
"""
function get_detailed_costs_benders(
    system::System,
    operational_costs::DataFrame,
    settings::NamedTuple;
    scaling::Float64=1.0
)
    # Get fixed costs (Investment, FixedOM) from system
    fixed_costs = get_fixed_costs_benders(system, settings; scaling)

    # Apply discounting to operational costs if needed
    period_index = system.time_data[:Electricity].period_index
    discount_rate = settings.DiscountRate
    period_lengths = settings.PeriodLengths
    period_length = period_lengths[period_index]
    period_start_year = total_years(period_lengths[1:period_index-1])
    discount_factor = present_value_factor(discount_rate, period_start_year)
    opexmult = present_value_annuity_factor(discount_rate, period_lengths[period_index])

    if isempty(operational_costs)
        return (discounted=fixed_costs.discounted, undiscounted=fixed_costs.undiscounted)
    end

    # Apply discounting to operational costs
    op_discounted = operational_costs
    op_undiscounted = deepcopy(operational_costs)
    # Discounted: Variable costs are raw sums; they get the full opex multiplier
    op_discounted.value .*= discount_factor * opexmult
    # Undiscounted: Variable costs need to be multiplied by period length to get CF terms
    op_undiscounted.value .*= period_length

    # Combine fixed costs with operational costs and return the result
    return (
        discounted = vcat(fixed_costs.discounted, op_discounted),
        undiscounted = vcat(fixed_costs.undiscounted, op_undiscounted)
    )
end

"""
    get_fixed_costs_benders(system::System, settings::NamedTuple; scaling::Float64=1.0)

Compute fixed costs (Investment, FixedOM) from the planning problem.
Returns (discounted=df, undiscounted=df) for Benders decomposition.
"""
function get_fixed_costs_benders(system::System, settings::NamedTuple; scaling::Float64=1.0)
    # Ensure cf_period_* attributes are available for undiscounted cost calculations
    undo_discount_fixed_costs!(system, settings)

    zones = String[]
    types = String[]
    categories = Symbol[]
    values_discounted = Float64[]
    values_undiscounted = Float64[]

    edges, edge_asset_map = get_edges(system, return_ids_map=true)
    storages, storage_asset_map = get_storages(system, return_ids_map=true)

    # Collect fixed costs from edges (Investment/FixedOM are both discounted and undiscounted at period start)
    for e in edges
        inv_pv, inv_cf = compute_investment_cost(e)
        fom_pv, fom_cf = compute_fixed_om_cost(e)

        (inv_pv == 0 && inv_cf == 0 && fom_pv == 0 && fom_cf == 0) && continue

        zone = get_zone_name(e)
        asset_type = get_type(edge_asset_map[id(e)])

        for (category, cost_pv, cost_cf) in [(:Investment, inv_pv, inv_cf), (:FixedOM, fom_pv, fom_cf)]
            (cost_pv == 0 && cost_cf == 0) && continue
            push!(zones, zone)
            push!(types, asset_type)
            push!(categories, category)
            push!(values_discounted, cost_pv)
            push!(values_undiscounted, cost_cf)
        end
    end

    # Collect fixed costs from storages (Investment/FixedOM are both discounted and undiscounted at period start)
    for g in storages
        inv_pv, inv_cf = compute_investment_cost(g)
        fom_pv, fom_cf = compute_fixed_om_cost(g)

        (inv_pv == 0 && inv_cf == 0 && fom_pv == 0 && fom_cf == 0) && continue

        zone = get_zone_name(g)
        asset_type = get_type(storage_asset_map[id(g)])

        for (category, cost_pv, cost_cf) in [(:Investment, inv_pv, inv_cf), (:FixedOM, fom_pv, fom_cf)]
            (cost_pv == 0 && cost_cf == 0) && continue
            push!(zones, zone)
            push!(types, asset_type)
            push!(categories, category)
            push!(values_discounted, cost_pv)
            push!(values_undiscounted, cost_cf)
        end
    end

    # Apply discounting to fixed costs
    period_index = system.time_data[:Electricity].period_index
    discount_rate = settings.DiscountRate
    period_lengths = settings.PeriodLengths
    period_start_year = total_years(period_lengths[1:period_index-1])
    discount_factor = present_value_factor(discount_rate, period_start_year)

    # Investment/FixedOM values hold pv_period_* * capacity (PV at period start)
    values_discounted .*= discount_factor

    if scaling != 1.0
        values_discounted .*= scaling^2
        values_undiscounted .*= scaling^2
    end

    return (
        discounted = DataFrame(zone=zones, type=types, category=categories, value=values_discounted),
        undiscounted = DataFrame(zone=zones, type=types, category=categories, value=values_undiscounted)
    )
end

# Utilities for aggregation and validation
"""
    aggregate_costs_by_type(costs_df::DataFrame)

Aggregate detailed costs by asset type.
Returns a DataFrame with one row per (type, category) combination.
"""
function aggregate_costs_by_type(costs_df::DataFrame)
    if isempty(costs_df)
        return DataFrame(type=String[], category=Symbol[], value=Float64[])
    end
    return combine(groupby(costs_df, [:type, :category]), :value => sum => :value)
end

"""
    aggregate_costs_by_zone(costs_df::DataFrame)

Aggregate detailed costs by zone.
Returns a DataFrame with one row per (zone, category) combination.
"""
function aggregate_costs_by_zone(costs_df::DataFrame)
    if isempty(costs_df)
        return DataFrame(zone=String[], category=Symbol[], value=Float64[])
    end
    return combine(groupby(costs_df, [:zone, :category]), :value => sum => :value)
end

"""
    aggregate_operational_costs(cost_dfs::Vector{DataFrame})

Aggregate operational costs from multiple subproblems into a single DataFrame.
Sums values across subproblems for each (zone, type, category) combination.

Used for Benders decomposition where operational costs is distributed across multiple subproblems.
"""
function aggregate_operational_costs(cost_dfs::Vector{DataFrame})
    if all(isempty, cost_dfs)
        return DataFrame(zone=String[], type=String[], category=Symbol[], value=Float64[])
    end
    
    combined = reduce(vcat, filter(!isempty, cost_dfs))
    return combine(groupby(combined, [:zone, :type, :category]), :value => sum => :value)
end

"""
    add_total_row!(df::DataFrame, group_col::Symbol)

Add `Total` row and `Total` column to the DataFrame.
"""
function add_total_row!(df::DataFrame, group_col::Symbol)
    if isempty(df)
        return df
    end
    
    # Total for each category
    total_by_category = combine(groupby(df, :category), :value => sum => :value)
    total_by_category[!, group_col] .= "Total"
    
    # Overall total
    grand_total = sum(total_by_category.value)
    total_row = DataFrame(group_col => ["Total"], :category => [:Total], :value => [grand_total])

    append!(df, total_by_category)
    append!(df, total_row)

    return df
end

function validate_total_cost(
    df::DataFrame,
    model::Union{Model,NamedTuple}, 
    discounted::Bool, 
    scaling::Float64; 
    validation_tolerance::Float64=1e-6
)::Bool
    # Validate the total cost against the objective value
    # Get objective value for validation (apply same discounting/scaling)
    if discounted
        objective_value = value(model[:eDiscountedFixedCost]) + value(model[:eDiscountedVariableCost]) * scaling^2
    else
        objective_value = value(model[:eFixedCost]) + value(model[:eVariableCost]) * scaling^2
    end
    grand_total = only(df[df.category .== :Total, :value])
    validation_diff = abs(grand_total - objective_value)
    is_valid = validation_diff < validation_tolerance * max(abs(objective_value), 1.0)
    !is_valid && @warn "Objective value validation failed. Validation difference: $validation_diff"
    return is_valid
end

"""
    reshape_costs_wide(df::DataFrame, group_col::Symbol)

Reshape cost DataFrame from long to wide format.
"""
function reshape_costs_wide(df::DataFrame, group_col::Symbol)
    if isempty(df)
        return df
    end
    
    wide_df = unstack(df, group_col, :category, :value, fill=0.0)
    
    cost_cols = [col for col in names(wide_df) if col != string(group_col) && Symbol(col) in COST_CATEGORIES]
    if !isempty(cost_cols)
        wide_df[!, :Total] = sum(wide_df[!, col] for col in cost_cols)
    end
    
    return wide_df
end
