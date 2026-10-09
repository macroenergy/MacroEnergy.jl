"""
Loss outputs - extraction and output of the commodity lost on lossy edges.

The loss of an edge is computed from its flow variables by `loss(e, t)`: `loss_fraction × flow` for
a unidirectional edge, and `loss_fraction × (flow_pos + flow_neg)` for a bidirectional one.
"""

@doc raw"""
    write_losses(
        file_path::AbstractString,
        system::System,
        scaling::Float64;
        drop_cols::Vector{<:AbstractString}=String[]
    )

Write the optimal losses of every edge with a nonzero `loss_fraction` to a file.

## Output format
Long format with columns for commodity, node\_in, node\_out, resource\_id, component\_id,
resource\_type, component\_type, variable, time, and value (loss per timestep).
In wide format, values are pivoted by time and component\_id.

# Arguments
- `file_path::AbstractString`: Path for the losses file
- `system::System`: The system containing the edges to analyze
- `scaling::Float64`: Scaling factor for the results
- `drop_cols::Vector{<:AbstractString}`: Columns to drop from the DataFrame

# Returns
- `nothing`

# Example
```julia
write_losses(joinpath(results_dir, "losses.csv"), system, 1.0)
```
"""
function write_losses(
    file_path::AbstractString,
    system::System,
    scaling::Float64;
    drop_cols::Vector{<:AbstractString}=String[]
)
    @info "Writing loss results to $file_path"

    loss_results = get_optimal_losses(system, scaling)

    if isempty(loss_results)
        @debug "No loss results found (no lossy edges in system)"
        return nothing
    end

    layout = get_output_layout(system, :Losses)
    if layout == "wide"
        loss_results = reshape_wide(loss_results, :time, :component_id, :value)
    end

    write_dataframe(file_path, loss_results, drop_cols)
    return nothing
end

"""
    write_losses(
        file_path::AbstractString,
        system::System,
        loss_dfs::Vector{DataFrame}
    )

Write loss results from pre-computed DataFrames to a file.

Used by the Benders decomposition workflow, where losses are collected from the subproblems of a
period and concatenated before writing.

# Arguments
- `file_path::AbstractString`: Path for the losses file
- `system::System`: The system (used for output layout settings)
- `loss_dfs::Vector{DataFrame}`: Vector of loss DataFrames to concatenate and write

# Returns
- `nothing`
"""
function write_losses(
    file_path::AbstractString,
    system::System,
    loss_dfs::Vector{DataFrame}
)
    @info "Writing loss results to $file_path"

    non_empty_dfs = filter(!isempty, loss_dfs)
    if isempty(non_empty_dfs)
        @debug "No loss results found (no lossy edges in system)"
        return nothing
    end

    loss_results = reduce(vcat, non_empty_dfs)

    layout = get_output_layout(system, :Losses)
    if layout == "wide"
        loss_results = reshape_wide(loss_results, :time, :component_id, :value)
    end

    write_dataframe(file_path, loss_results)
    return nothing
end

## Loss extraction functions ##

@doc raw"""
    get_optimal_losses(
        system::System,
        scaling::Float64
    )

Get the optimal losses of every edge in a system with a nonzero `loss_fraction`.

The loss at timestep t is `value(loss(e, t))`:
- unidirectional edge: `loss_fraction(e, t) × flow(e, t)`, lost at the end vertex;
- bidirectional edge: `loss_fraction(e, t) × (flow_pos(e, t) + flow_neg(e, t))`, each direction's
  share lost at the vertex receiving it.

# Arguments
- `system::System`: The system containing the edges to analyze
- `scaling::Float64`: Scaling factor for the results

# Returns
- `DataFrame`: Temporal losses with columns for commodity, node\_in, node\_out, resource\_id, component\_id, resource\_type, component\_type, variable, time, value

# Example
```julia
losses_df = get_optimal_losses(system, 1.0)
```
"""
function get_optimal_losses(system::System, scaling::Float64)::DataFrame
    @debug " -- Getting optimal loss values for the system"

    edges, edge_asset_map = get_edges(system, return_ids_map=true)
    edges = filter(lossy_edge, edges)

    if isempty(edges)
        @debug "No lossy edges found in the system to get loss values"
        return DataFrame()
    end

    losses_df = get_optimal_losses(edges, scaling; obj_asset_map=edge_asset_map)
    losses_df[!, (!isa).(eachcol(losses_df), Vector{Missing})]
end

function get_optimal_losses(
    objs::Vector{<:AbstractEdge},
    scaling::Float64;
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
)
    reduce(vcat, [get_optimal_losses(o, scaling; obj_asset_map) for o in objs])
end

function get_optimal_losses(
    obj::AbstractEdge,
    scaling::Float64;
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
)
    time_axis = time_interval(obj)
    loss_values = Float64[value(loss(obj, t)) * scaling for t in time_axis]

    if isempty(obj_asset_map)
        return DataFrame(
            case_name = fill(missing, length(time_axis)),
            commodity = fill(get_commodity_name(obj), length(time_axis)),
            node_in = fill(get_node_in(obj), length(time_axis)),
            node_out = fill(get_node_out(obj), length(time_axis)),
            resource_id = fill(get_component_id(obj), length(time_axis)),
            component_id = fill(get_component_id(obj), length(time_axis)),
            component_type = fill(get_type(obj), length(time_axis)),
            variable = fill(:loss, length(time_axis)),
            year = fill(missing, length(time_axis)),
            time = [t for t in time_axis],
            value = loss_values
        )
    else
        return DataFrame(
            case_name = fill(missing, length(time_axis)),
            commodity = fill(get_commodity_name(obj), length(time_axis)),
            node_in = fill(get_node_in(obj), length(time_axis)),
            node_out = fill(get_node_out(obj), length(time_axis)),
            resource_id = fill(get_resource_id(obj, obj_asset_map), length(time_axis)),
            component_id = fill(get_component_id(obj), length(time_axis)),
            resource_type = fill(get_type(obj_asset_map[id(obj)]), length(time_axis)),
            component_type = fill(get_type(obj), length(time_axis)),
            variable = fill(:loss, length(time_axis)),
            year = fill(missing, length(time_axis)),
            time = [t for t in time_axis],
            value = loss_values
        )
    end
end
