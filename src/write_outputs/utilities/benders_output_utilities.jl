function prepare_costs_benders(system::System, 
    bd_results::BendersResults, 
    subop_indices::Vector{Int64}, 
    settings::NamedTuple
)
    planning_problem = bd_results.planning_problem
    subop_sol = bd_results.subop_sol
    planning_variable_values = bd_results.planning_sol.values

    create_discounted_cost_expressions!(planning_problem, system, settings)
    compute_undiscounted_costs!(planning_problem, system, settings)

    # Evaluate the fixed cost expressions in the planning problem. Note that this expression has been re-built
    # in compute_undiscounted_costs! to utilize undiscounted costs and the Benders planning solutions that are 
    # stored in system. So, no need to re-evaluate the expression on planning_variable_values.
    fixed_cost = value(planning_problem[:eFixedCost])
    # Evaluate the discounted fixed cost expression on the Benders planning solutions
    discounted_fixed_cost = value(x -> planning_variable_values[name(x)], planning_problem[:eDiscountedFixedCost])

    # evaluate the variable cost expressions using the subproblem solutions
    variable_cost = evaluate_vtheta_in_expression(planning_problem, :eVariableCost, subop_sol, subop_indices)
    discounted_variable_cost = evaluate_vtheta_in_expression(planning_problem, :eDiscountedVariableCost, subop_sol, subop_indices)

    return (
        eFixedCost = fixed_cost,
        eVariableCost = variable_cost,
        eDiscountedFixedCost = discounted_fixed_cost,
        eDiscountedVariableCost = discounted_variable_cost
    )
end
    
"""
Collect flow results from all subproblems, handling distributed case.
"""
function collect_flow_results(case::Case, bd_results::BendersResults)
    if case.settings.BendersSettings[:Distributed]
        return collect_distributed_flows(bd_results)
    else
        return collect_local_flows(bd_results)
    end
end

"""
Collect flow results from subproblems on distributed workers.
"""
function collect_distributed_flows(bd_results::BendersResults)
    p_id = workers()
    np_id = length(p_id)
    flow_df = Vector{Vector{DataFrame}}(undef, np_id)
    @sync for i in 1:np_id
        @async flow_df[i] = @fetchfrom p_id[i] get_local_expressions(get_optimal_flow, DistributedArrays.localpart(bd_results.op_subproblem))
    end
    return reduce(vcat, flow_df)
end

"""
Collect flow results from local subproblems.
"""
function collect_local_flows(bd_results::BendersResults)
    flow_df = Vector{DataFrame}(undef, length(bd_results.op_subproblem))
    for i in eachindex(bd_results.op_subproblem)
        system = bd_results.op_subproblem[i][:system_local]
        flow_df[i] = get_optimal_flow(system)
    end
    return flow_df
end

"""
Convert DenseAxisArray to Dict, preserving axis information.
"""
function densearray_to_dict(arr::JuMP.Containers.DenseAxisArray)
    ndims = length(arr.axes)
    
    if ndims == 1
        return Dict(idx => JuMP.value(arr[idx]) for idx in arr.axes[1])
    elseif ndims == 2
        return Dict((i, j) => JuMP.value(arr[i, j]) for i in arr.axes[1], j in arr.axes[2])
    else
        return Dict(idx_tuple => JuMP.value(arr[idx_tuple...]) 
            for idx_tuple in Iterators.product(arr.axes...))
    end
end

"""
Convert Dict back to DenseAxisArray.
"""
function dict_to_densearray(dict::AbstractDict)
    first_key = first(keys(dict))
    
    if first_key isa Tuple
        ndims = length(first_key)
        
        # Extract unique values for each dimension from the dictionary keys
        # This will make sure to map the dictionary keys to the DenseAxisArray indices
        key_list = collect(keys(dict))
        all_axes = []
        for dim in 1:ndims
            axis_vals = sort(unique([k[dim] for k in key_list]))
            push!(all_axes, axis_vals)
        end
        
        # Create data array from the dictionary values
        data = [get(dict, idx_tuple, NaN) for idx_tuple in Iterators.product(all_axes...)]
        
        return JuMP.Containers.DenseAxisArray(data, all_axes...)
    elseif isa(first_key, Int64)
        # Fallback to 1D case if keys are not tuples
        indices = sort(collect(keys(dict)))
        values = [dict[i] for i in indices]
        return JuMP.Containers.DenseAxisArray(values, indices)
    else
        error("Unsupported key type: $(typeof(first_key))")
    end
end

"""
    populate_slack_vars_from_subproblems!(
        period::System,
        slack_vars::Dict{Tuple{Symbol,Symbol}, <:AbstractDict}
    )

Populate slack variables from Benders subproblems back into the planning problem system.

Converts collected slack variable dictionaries back to DenseAxisArray format and assigns them
to the appropriate nodes in the planning problem.

# Arguments
- `period::System`: The planning problem system
- `slack_vars::Dict{Tuple{Symbol,Symbol}, <:AbstractDict}`: Dictionary mapping (node_id, slack_vars_key) to slack variable data

# Returns
- `nothing`
"""
function populate_slack_vars_from_subproblems!(period::System, slack_vars::Dict{Tuple{Symbol,Symbol}, <:AbstractDict})
    for (node_id, slack_vars_key) in keys(slack_vars)
        node = find_node(period, node_id)
        @assert !isnothing(node)
        # Convert dict back to DenseAxisArray before assigning to the node
        # This will make sure the slack variables are stored in the correct format
        node.policy_slack_vars[slack_vars_key] = dict_to_densearray(slack_vars[(node_id, slack_vars_key)])
    end
    return nothing
end

"""
    collect_distributed_policy_slack_vars(bd_results::BendersResults)

Collect policy slack variables from distributed Benders subproblems across multiple workers.

# Arguments
- `bd_results::BendersResults`: Benders decomposition results containing distributed subproblems

# Returns
- Dictionary with structure: period_index => (node_id, slack_vars_key) => {axis_idx => value}
"""
function collect_distributed_policy_slack_vars(bd_results::BendersResults)
    p_id = workers()
    np_id = length(p_id)
    slack_vars = Vector{Dict{Int64, Dict{Tuple{Symbol,Symbol}, Dict{Int64, Float64}}}}(undef, np_id)
    @sync for i in 1:np_id
        @async slack_vars[i] = @fetchfrom p_id[i] collect_local_slack_vars(DistributedArrays.localpart(bd_results.op_subproblem))
    end
    
    # Merge dictionaries by period_index
    # Structure: period_index => (node_id, slack_vars_key) => {axis_idx => value}
    return merge_distributed_slack_vars_dicts(slack_vars)
end

"""
    collect_local_slack_vars(subproblems_local::Vector{Dict{Any,Any}})

Collect policy slack variables from local Benders subproblems on this worker.

Iterates through subproblems and extracts slack variables from nodes, converting them
from DenseAxisArray to dictionary format for distributed collection.

# Arguments
- `subproblems_local::Vector{Dict{Any,Any}}`: Local subproblems on this worker

# Returns
- Dictionary with structure: period_index => (node_id, slack_vars_key) => {axis_idx => value}
"""
function collect_local_slack_vars(subproblems_local::Vector{Dict{Any,Any}})
    slack_vars = Dict{Int64, Dict{Tuple{Symbol, Symbol}, Dict{Int64, Float64}}}()
    for i in eachindex(subproblems_local)
        system = subproblems_local[i][:system_local]
        for node in filter(n -> n isa Node, system.locations)
            period_index = system.time_data[:Electricity].period_index
            for slack_vars_key in keys(policy_slack_vars(node))
                # Create tuple key with (node_id, slack_vars_key) to keep track of the metadata
                key = (node.id, slack_vars_key)
                
                # Convert DenseAxisArray to Dict before assigning to the period_dict
                slack_array = policy_slack_vars(node)[slack_vars_key]
                axis_dict = densearray_to_dict(slack_array)
                
                # Ensure period_index dict exists
                period_dict = get!(slack_vars, period_index, Dict{Tuple{Symbol, Symbol}, Dict{Int64, Float64}}())
                
                # Merge axis dictionaries (different subproblems have different time indices)
                if haskey(period_dict, key)
                    merge!(period_dict[key], axis_dict)
                else
                    period_dict[key] = axis_dict
                end
            end
        end
    end
    return slack_vars
end

"""
    merge_distributed_slack_vars_dicts(
        worker_results::Vector{Dict{Int64, Dict{Tuple{Symbol,Symbol}, Dict}}}
    )

Helper function that combines results from multiple workers where each worker
returns a nested dictionary structure: period_idx => (node_id, slack_vars_key) => data_dict.

# Arguments
- `worker_results::Vector{Dict{Int64, Dict{K, Dict}}}`: Vector of dictionaries from each worker

# Returns
- Merged dictionary with structure: period_idx => (node_id, slack_vars_key) => merged_data_dict
"""
function merge_distributed_slack_vars_dicts(
    worker_results::Vector{<:AbstractDict{Int64, <:AbstractDict{Tuple{Symbol,Symbol}, <:AbstractDict}}}
)
    merged = Dict{Int64, Dict{Tuple{Symbol,Symbol}, Dict}}()
    
    for worker_dict in worker_results
        for (period_idx, period_dict) in worker_dict
            # Ensure period exists in merged dict
            if !haskey(merged, period_idx)
                merged[period_idx] = Dict{Tuple{Symbol,Symbol}, Dict}()
            end
            
            # Merge inner dictionaries for this period
            for (key, data_dict) in period_dict
                if haskey(merged[period_idx], key)
                    # If same (node_id, slack_vars_key) exists, merge the axis dictionaries
                    merge!(merged[period_idx][key], data_dict)
                else
                    merged[period_idx][key] = copy(data_dict)
                end
            end
        end
    end
    
    return merged
end

"""
    populate_constraint_duals_from_subproblems!(
        period::System,
        constraint_duals::Dict{Symbol, Dict{Symbol, <: AbstractDict}},
        ::Type{<:AbstractTypeConstraint}
    )

# Arguments
- `period::System`: The planning problem
- `constraint_duals::Dict{Symbol, Dict{Symbol, Dict}}`: The collected constraint duals
- `::Type{<:AbstractTypeConstraint}`: The constraint type to prepare duals for

# Returns
- `nothing`

Moves constraint duals from collected data back into the planning problem..
"""
function populate_constraint_duals_from_subproblems!(period::System, constraint_duals::Dict{Symbol, <: AbstractDict{Symbol, <: AbstractDict}}, ::Type{<:AbstractTypeConstraint})
    for (node_id, balance_dict) in constraint_duals
        node = find_node(period, node_id)
        @assert !isnothing(node) "Node $node_id not found in planning problem"
        
        # Find the BalanceConstraint
        constraint = get_constraint_by_type(node, BalanceConstraint)
        isnothing(constraint) && continue
        
        # Initialize constraint_dual dict if missing
        if ismissing(constraint.constraint_dual)
            constraint.constraint_dual = Dict{Symbol, Vector{Float64}}()
        end
        
        # For each balance equation, convert time_dict back to vector
        for (balance_id, time_dict) in balance_dict
            time_indices = sort(collect(keys(time_dict)))
            dual_values = [time_dict[t] for t in time_indices]
            constraint.constraint_dual[balance_id] = dual_values
        end
        # verify the constraint duals have all time indices
        for dual_values in values(constraint.constraint_dual)
            @assert length(dual_values) == length(time_interval(node))
        end
    end
    
    return nothing
end

"""
    collect_distributed_constraint_duals(
        bd_results::BendersResults,
        ::Type{<:AbstractTypeConstraint}
    )

# Arguments
- `bd_results::BendersResults`: Benders decomposition results containing subproblems
- `::Type{BalanceConstraint}`: The constraint type to collect duals for

# Returns
- `Dict{Int64, Dict{Symbol, Dict{Symbol, Dict}}}`: A nested dictionary structure containing the constraint duals

The returned dictionary has the following structure:
- period_index => node_id => balance_id => {time_idx => dual_value}
"""
function collect_distributed_constraint_duals(bd_results::BendersResults, ::Type{BalanceConstraint})
    p_id = workers()
    np_id = length(p_id)
    constraint_duals = Vector{Dict{Int64, Dict{Symbol, Dict{Symbol, Dict}}}}(undef, np_id)
    @sync for i in 1:np_id
        @async constraint_duals[i] = @fetchfrom p_id[i] collect_local_constraint_duals(
            DistributedArrays.localpart(bd_results.op_subproblem),
            BalanceConstraint
        )
    end
    
    # Merge dictionaries
    # Structure: period_idx => node_id => balance_id => {time_idx => dual_value}
    return merge_distributed_balance_duals(constraint_duals)
end

"""
    collect_local_constraint_duals(
        subproblems_local::Vector{<: AbstractDict{Any,Any}},
        ::Type{BalanceConstraint}
    )

Collect BalanceConstraint duals from local subproblems on this worker.

# Arguments
- `subproblems_local::Vector{Dict{Any,Any}}`: Local subproblems on this worker
- `::Type{BalanceConstraint}`: The constraint type to collect duals for

# Returns
- Dictionary with structure: period_index => node_id => balance_id => {time_idx => dual_value}
"""
function collect_local_constraint_duals(
    subproblems_local::Vector{ <: AbstractDict},
    ::Type{BalanceConstraint}
)
    constraint_duals = Dict{Int64, Dict{Symbol, Dict{Symbol, Dict}}}()
    
    for i in eachindex(subproblems_local)
        system = subproblems_local[i][:system_local]
        period_index = system.time_data[:Electricity].period_index
        
        for node in filter(n -> n isa Node, system.locations)
            # Find BalanceConstraint on this node
            constraint = get_constraint_by_type(node, BalanceConstraint)
            isnothing(constraint) && continue
            ismissing(constraint.constraint_ref) && continue
            
            # Extract dual values if not already extracted
            if ismissing(constraint_dual(constraint))
                set_constraint_dual!(constraint, node)
            end
            
            # Get the dictionary of dual values for all balance equations
            duals_dict = constraint_dual(constraint)
            ismissing(duals_dict) && continue
            
            # Ensure period and node dicts exist
            if !haskey(constraint_duals, period_index)
                constraint_duals[period_index] = Dict{Symbol, Dict{Symbol, Dict}}()
            end
            if !haskey(constraint_duals[period_index], node.id)
                constraint_duals[period_index][node.id] = Dict{Symbol, Dict}()
            end
            
            # For each balance equation, store duals as time_idx => value
            for (balance_id, dual_values) in duals_dict
                # Convert vector to dict mapping time indices to values
                time_indices = collect(time_interval(node))
                dual_dict = Dict(time_indices[i] => dual_values[i] for i in eachindex(time_indices))
                
                # Merge time dictionaries (different subproblems have different time indices)
                if haskey(constraint_duals[period_index][node.id], balance_id)
                    merge!(constraint_duals[period_index][node.id][balance_id], dual_dict)
                else
                    constraint_duals[period_index][node.id][balance_id] = dual_dict
                end
            end
        end
    end
    
    return constraint_duals
end

"""
    merge_distributed_balance_duals(
        worker_results::Vector{<:AbstractDict{Int64, <:AbstractDict{Symbol, <:AbstractDict{Symbol, <:AbstractDict}}}}
    )

Helper function that combines results from multiple workers where each worker
returns a nested dictionary structure: period_idx => node_id => balance_id => time_dict.

# Arguments
- `worker_results::Vector{<:AbstractDict{Int64, <:AbstractDict{Symbol, <:AbstractDict{Symbol, <:AbstractDict}}}}`: Vector of dictionaries from each worker

# Returns
- Merged dictionary with structure: period_idx => node_id => balance_id => {time_idx => dual_value}
"""
function merge_distributed_balance_duals(
    worker_results::Vector{<:AbstractDict{Int64, <:AbstractDict{Symbol, <:AbstractDict{Symbol, <:AbstractDict}}}}
)
    merged_duals = Dict{Int64, Dict{Symbol, Dict{Symbol, Dict}}}()
    
    for worker_dict in worker_results
        for (period_idx, period_dict) in worker_dict
            # Make sure period exists
            if !haskey(merged_duals, period_idx)
                merged_duals[period_idx] = Dict{Symbol, Dict{Symbol, Dict}}()
            end
            
            # Merge inner dictionaries for this period
            for (node_id, balance_dict) in period_dict
                if !haskey(merged_duals[period_idx], node_id)
                    merged_duals[period_idx][node_id] = Dict{Symbol, Dict}()
                end
                
                # Merge balance equation dictionaries
                for (balance_id, time_dict) in balance_dict
                    if haskey(merged_duals[period_idx][node_id], balance_id)
                        # Merge time index dictionaries from different workers
                        merge!(merged_duals[period_idx][node_id][balance_id], time_dict)
                    else
                        merged_duals[period_idx][node_id][balance_id] = copy(time_dict)
                    end
                end
            end
        end
    end
    
    return merged_duals
end

"""
    collect_local_constraint_duals(
        subproblems_local::Vector{Dict{Any,Any}},
        constraint_type::Type{<:AbstractTypeConstraint}
    )

Fallback function that throws an error if the constraint type is not supported.

This is a generic fallback method that should be specialized for specific constraint types
(e.g., `BalanceConstraint`). If called with an unsupported constraint type, it throws a
descriptive `MethodError`.

# Arguments
- `subproblems_local::Vector{Dict{Any,Any}}`: Local subproblems on this worker
- `constraint_type::Type{<:AbstractTypeConstraint}`: The constraint type to collect duals for

# Throws
- `MethodError`: Always thrown to indicate the constraint type is not supported
"""
function collect_local_constraint_duals(
    subproblems_local::Vector{Dict{Any,Any}},
    constraint_type::Type{<:AbstractTypeConstraint}
)
    throw(MethodError(collect_local_constraint_duals, 
        (typeof(subproblems_local), typeof(constraint_type)),
        "Constraint type $(typeof(constraint_type)) not supported for local constraint dual collection."
    ))
end
