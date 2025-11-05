# ============================================================================
# Dual Value Export Functions
# ============================================================================

"""
    write_duals(results_dir::AbstractString, system::System, scaling::Float64=1.0)

Write dual values for all supported constraint types to separate CSV files.

Currently, this function exports dual values for:
- Balance constraints → `balance_duals.csv`
- CO2 cap constraints → `co2_cap_duals.csv`

# Arguments
- `results_dir::AbstractString`: Directory where CSV files will be written
- `system::System`: The system containing solved constraints with dual values
- `scaling::Float64`: Scaling factor for the dual values (e.g. to account for discounting in multi-period models)

# Examples
```julia
# After solving the model
(case, model) = solve_case(case, optimizer);
system = case.systems[1]; # single period case

# Export all dual values
write_duals("results/", system)
```

# See Also
- [`write_balance_duals`](@ref): Export balance constraint duals
- [`write_co2_cap_duals`](@ref): Export CO2 cap constraint duals
"""
function write_duals(
    results_dir::AbstractString,
    system::System,
    scaling::Float64=1.0
)
    @info "Writing constraint dual values to $results_dir"
    
    # Export each constraint type to its own file
    write_balance_duals(results_dir, system, scaling)
    write_co2_cap_duals(results_dir, system, scaling)
    
    return nothing
end

"""
    write_balance_duals(results_dir::AbstractString, system::System, scaling::Float64=1.0)

Write balance constraint dual values (marginal prices) to CSV file.

Extracts dual values from the `:demand` balance equation on all nodes and exports them to 
`balance_duals.csv`. The dual values are automatically rescaled by subperiod weights
to provide proper marginal values per unit of energy/commodity.

Note: Only nodes with a `:demand` balance equation will be included in the output. Nodes 
with other balance equations (e.g., `:emissions`, `:co2_storage`) are skipped.

# Output Format
Wide-format CSV with:
- Rows: Time steps
- Columns: Node IDs
- Values: Rescaled dual values (shadow prices) for the `:demand` balance equation

# Arguments
- `results_dir::AbstractString`: Directory where CSV file will be written
- `system::System`: The system containing solved balance constraints
- `scaling::Float64`: Scaling factor for the dual values (e.g. to account for discounting in multi-period models)

# Examples
```julia
write_balance_duals("results/", system)
# Creates: results/balance_duals.csv
```
"""
function write_balance_duals(
    results_dir::AbstractString,
    system::System,
    scaling::Float64=1.0
)
    @info "Writing balance constraint dual values to $results_dir"

    filename = "balance_duals.csv"
    file_path = joinpath(results_dir, filename)

    balance_duals = Vector{Vector{Float64}}()
    node_ids = Vector{Symbol}()

    for node in filter(n -> n isa Node, system.locations)
        constraint = get_constraint_by_type(node, BalanceConstraint)
        isnothing(constraint) && continue
        # Skip if constraint has no reference or dual values
        if ismissing(constraint.constraint_ref) && ismissing(constraint.constraint_dual)
            continue
        end
        
        # Extract dual values if not already extracted
        if ismissing(constraint_dual(constraint))
            set_constraint_dual!(constraint, node)
        end
        
        # Get the dictornary of dual values for all balance equations
        duals_dict = constraint_dual(constraint)
        
        # Export only the :demand balance duals (skip if not present)
        !haskey(duals_dict, :demand) && continue
        
        # Add node ID
        push!(node_ids, id(node))

        # Compute subperiod weights for rescaling
        weights = Float64[subperiod_weight(node, current_subperiod(node, t)) for t in time_interval(node)]
        
        # Rescale dual values by subperiod weights
        push!(balance_duals, duals_dict[:demand] ./ (weights .* scaling))
    end

    df = DataFrame(balance_duals, node_ids, copycols=false)
    write_dataframe(file_path, df)
    @debug "Wrote $(nrow(df)) time steps and $(length(node_ids)) nodes for balance constraints to CSV file: $file_path"

    return nothing
end

"""
    write_co2_cap_duals(results_dir::AbstractString, system::System, scaling::Float64=1.0)

Write CO2 cap constraint dual values (carbon prices) and penalty costs to CSV file.

Extracts dual values from CO2 cap policy budget constraints and exports them to
`co2_cap_duals.csv`. If slack variables exist, also exports penalty costs.

# Output Format
Long-format CSV with columns:
- `node`: Node ID
- `co2_shadow_price`: Carbon price
- `co2_penalty_cost`: Total penalty cost across subperiods (if slack variables exist)

# Arguments
- `results_dir::AbstractString`: Directory where CSV file will be written
- `system::System`: The system containing solved CO2 cap constraints
- `scaling::Float64`: Scaling factor for the dual values (e.g. to account for discounting in multi-period models)

# Examples
```julia
write_co2_cap_duals("results/", system)
# Creates: results/co2_cap_duals.csv
```
"""
function write_co2_cap_duals(
    results_dir::AbstractString,
    system::System,
    scaling::Float64=1.0
)
    @info "Writing CO2 cap constraint dual values to $results_dir"

    filename = "co2_cap_duals.csv"
    file_path = joinpath(results_dir, filename)

    # Constraint type
    ct_type = CO2CapConstraint

    node_ids = Vector{Symbol}()
    co2_shadow_prices = Vector{Float64}()
    co2_slack_vars = Vector{Float64}()

    for node in filter(n -> n isa Node, system.locations)
        # Skip nodes without CO2 cap policy budget constraint
        !haskey(policy_budgeting_constraints(node), ct_type) && continue
        
        # Get the constraint reference
        constraint = policy_budgeting_constraints(node, ct_type)

        # Store node ID
        push!(node_ids, id(node))

        # Get CO2 shadow prices
        co2_shadow_price = -dual(constraint) / scaling
        push!(co2_shadow_prices, co2_shadow_price)

        # Calculate penalty cost if slack variables exist
        if haskey(price_unmet_policy(node), ct_type)
            
            # Get slack variables and penalty price
            slack_var_key = Symbol(string(ct_type) * "_Slack")
            slack_vars = value.(policy_slack_vars(node)[slack_var_key])

            # Total penalty cost across all subperiods
            co2_slack_sum = sum(subperiod_indices(node)) do w
                subperiod_weight(node, w) * slack_vars[w]
            end

            push!(co2_slack_vars, co2_slack_sum)
        end
    end
    
    # Check if any constraints were found
    if isempty(co2_shadow_prices)
        @info "No CO2 cap constraints found to export"
        return nothing
    end
    
    # Build DataFrame with appropriate columns
    df = DataFrame(Node = node_ids, CO2_Shadow_Price = co2_shadow_prices)
    
    if !isempty(co2_slack_vars)
        df[!, :CO2_Slack] = co2_slack_vars
    end

    write_dataframe(file_path, df)
    @debug "Wrote $(nrow(df)) CO2 cap constraint dual values to: $file_path"

    return nothing
end

function compute_variable_cost_discount_scaling(period_idx::Int, settings::NamedTuple)
    discount_rate = settings.DiscountRate
    period_lengths = settings.PeriodLengths
    
    cum_years = sum(@view(period_lengths[1:period_idx-1]); init=0)
    
    discount_factor = 1 / ((1 + discount_rate)^cum_years)
    
    period_length = period_lengths[period_idx]
    opexmult = sum(1 / (1 + discount_rate)^i for i in 1:period_length)
    
    return discount_factor * opexmult
end
