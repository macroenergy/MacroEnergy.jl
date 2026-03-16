"""
Non-served demand outputs - extraction and output of non-served demand data from nodes.
"""

"""
    write_non_served_demand(
        file_path::AbstractString, 
        system::System; 
        scaling::Float64=1.0, 
        drop_cols::Vector{<:AbstractString}=String[]
    )

Write the optimal non-served demand results for all nodes in a system to a file.
The extension of the file determines the format of the file (CSV, CSV.GZ, or Parquet).

Only nodes that have non-served demand variables (i.e., nodes with `max_nsd != [0.0]`) 
in the input data are included in the output.

## Output Format
- **Long format**: Includes `component_id` and `segment` as separate columns
- **Wide format**: Uses compound column names `{component_id}_seg{segment}` (e.g., `elec_node_seg1`, `elec_node_seg2`)

# Arguments
- `file_path::AbstractString`: The path to the file where the results will be written
- `system::System`: The system containing the nodes to analyze
- `scaling::Float64`: The scaling factor for the results (default: 1.0)
- `drop_cols::Vector{<:AbstractString}`: Columns to drop from the DataFrame (default: empty)

# Returns
- `nothing`: The function returns nothing, but writes the results to the file

# Example
```julia
write_non_served_demand("non_served_demand.csv", system)
write_non_served_demand("non_served_demand.csv", system, scaling=1000.0)
```
"""
function write_non_served_demand(
    file_path::AbstractString, 
    system::System; 
    scaling::Float64=1.0, 
    drop_cols::Vector{<:AbstractString}=String[]
)
    @info "Writing non-served demand results to $file_path"

    # Get non-served demand results
    nsd_results = get_optimal_non_served_demand(system; scaling)
    
    if isempty(nsd_results)
        @debug "No non-served demand results found (no nodes have NSD variables)"
        return nothing
    end

    # Get output layout preference
    layout = get_output_layout(system, :NonServedDemand)
    
    if layout == "wide"
        # Create compound column name: component_id_seg{segment}
        nsd_results[!, :component_id_seg] = string.(nsd_results.component_id) .* "_seg" .* string.(nsd_results.segment)
        nsd_results = reshape_wide(nsd_results, :time, :component_id_seg, :value)
    end
    
    write_dataframe(file_path, nsd_results, drop_cols)
    return nothing
end

# Function to write non-served demand results from multiple dataframes
# This function is used when the results are distributed across multiple processes (Benders)
function write_non_served_demand(
    file_path::AbstractString, 
    system::System, 
    nsd_dfs::Vector{DataFrame}
)
    @info "Writing non-served demand results to $file_path"

    # Filter out empty DataFrames and concatenate
    non_empty_dfs = filter(!isempty, nsd_dfs)
    if isempty(non_empty_dfs)
        @debug "No non-served demand results found (no nodes have NSD variables)"
        return nothing
    end
    
    nsd_results = reduce(vcat, non_empty_dfs)
    
    # Reshape if wide layout requested
    layout = get_output_layout(system, :NonServedDemand)
    if layout == "wide"
        # Create compound column name: component_id_seg{segment}
        nsd_results[!, :component_id_seg] = string.(nsd_results.component_id) .* "_seg" .* string.(nsd_results.segment)
        nsd_results = reshape_wide(nsd_results, :time, :component_id_seg, :value)
    end
    
    write_dataframe(file_path, nsd_results)
    return nothing
end

## Non-served demand extraction functions ##

"""
    get_optimal_non_served_demand(system::System; scaling::Float64=1.0)

Get the optimal non-served demand values for all nodes in a system.

Only nodes that have non-served demand variables are included in the output.

# Arguments
- `system::System`: The system containing the nodes to analyze
- `scaling::Float64`: The scaling factor for the results (default: 1.0)

# Returns
- `DataFrame`: A dataframe containing the optimal non-served demand values, 
  with columns for commodity, zone, component_id, variable, segment, time, and value.
  Returns an empty DataFrame if no nodes have NSD variables.

# Example
```julia
get_optimal_non_served_demand(system)
```
"""
function get_optimal_non_served_demand(system::System; scaling::Float64=1.0)
    @debug " -- Getting optimal non-served demand values for the system"
    
    # Get all nodes and filter to those with non-served demand variables
    nodes_with_nsd = filter(n -> !isempty(non_served_demand(n)), get_nodes(system))
    
    if isempty(nodes_with_nsd)
        return DataFrame()
    end
    
    nsd = get_optimal_non_served_demand(nodes_with_nsd, scaling)
    nsd[!, (!isa).(eachcol(nsd), Vector{Missing})] # remove missing columns
end

"""
    get_optimal_non_served_demand(nodes::Vector{<:Node}, scaling::Float64=1.0)

Get the optimal non-served demand values for a list of nodes.

# Arguments
- `nodes::Vector{<:Node}`: The nodes to extract NSD values from
- `scaling::Float64`: The scaling factor for the results

# Returns
- `DataFrame`: A dataframe containing the optimal non-served demand values
"""
function get_optimal_non_served_demand(nodes::Vector{<:Node}, scaling::Float64=1.0)
    if isempty(nodes)
        return DataFrame()
    end
    reduce(vcat, [get_optimal_non_served_demand(n, scaling) for n in nodes])
end

"""
    get_optimal_non_served_demand(node::Node, scaling::Float64=1.0)

Get the optimal non-served demand values for a single node.

# Arguments
- `node::Node`: The node to extract NSD values from
- `scaling::Float64`: The scaling factor for the results

# Returns
- `DataFrame`: A dataframe containing the optimal non-served demand values for the node
"""
function get_optimal_non_served_demand(node::Node, scaling::Float64=1.0)
    if isempty(non_served_demand(node))
        return DataFrame()
    end
    
    time_axis = time_interval(node)
    num_segments = length(segments_non_served_demand(node))
    total_rows = num_segments * length(time_axis)
    
    return DataFrame(
        case_name = fill(missing, total_rows),
        commodity = fill(get_commodity_name(node), total_rows),
        zone = fill(get_zone_name(node), total_rows),
        component_id = fill(id(node), total_rows),
        component_type = fill(get_type(node), total_rows),
        variable = fill(:non_served_demand, total_rows),
        year = fill(missing, total_rows),
        segment = Int[s for s in 1:num_segments for t in time_axis],
        time = Int[t for s in 1:num_segments for t in time_axis],
        value = Float64[value(non_served_demand(node, s, t)) * scaling for s in 1:num_segments for t in time_axis]
    )
end
