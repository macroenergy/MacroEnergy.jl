"""
Curtailment outputs - extraction and output of VRE curtailment data.

Curtailment is the difference between available VRE generation (capacity × availability factor)
and actual generation (flow). It represents energy that could have been produced but was not
dispatched, e.g., due to system constraints or economic curtailment.
"""

@doc raw"""
    write_curtailment(
        file_path::AbstractString,
        system::System;
        scaling::Float64=1.0,
        drop_cols::Vector{<:AbstractString}=String[]
    )

Write the optimal curtailment results for VRE assets to a file.

## Output format
Long format with columns for commodity, zone, resource\_id, component\_id,
resource\_type, component\_type, variable, time, and value (curtailment per timestep).
In wide format, values are pivoted by time and resource\_id.

# Arguments
- `file_path::AbstractString`: Path for the curtailment file
- `system::System`: The system containing VRE assets to analyze
- `scaling::Float64`: Scaling factor for the results (default: 1.0)
- `drop_cols::Vector{<:AbstractString}`: Columns to drop from the DataFrame

# Returns
- `nothing`

# Example
```julia
write_curtailment(joinpath(results_dir, "curtailment.csv"), system)
```
"""
function write_curtailment(
    file_path::AbstractString,
    system::System;
    scaling::Float64=1.0,
    drop_cols::Vector{<:AbstractString}=String[]
)
    @info "Writing curtailment results to $file_path"

    curtailment_results = get_optimal_curtailment(system; scaling)

    if isempty(curtailment_results)
        @debug "No curtailment results found (no VRE assets in system)"
        return nothing
    end

    # Get output layout preference
    layout = get_output_layout(system, :Curtailment)

    if layout == "wide"
        curtailment_results = reshape_wide(curtailment_results, :time, :resource_id, :value)
    end

    write_dataframe(file_path, curtailment_results, drop_cols)

    return nothing
end

"""
    write_curtailment(
        file_path::AbstractString,
        system::System,
        curtailment_dfs::Vector{DataFrame}
    )

Write curtailment results from pre-computed DataFrames to a file.

Used internally by the Benders decomposition workflow when curtailment data
is collected from multiple subproblem periods and concatenated before writing.

# Arguments
- `file_path::AbstractString`: Path for the curtailment file
- `system::System`: The system (used for output layout settings)
- `curtailment_dfs::Vector{DataFrame}`: Vector of curtailment DataFrames to concatenate and write

# Returns
- `nothing`
"""
function write_curtailment(
    file_path::AbstractString,
    system::System,
    curtailment_dfs::Vector{DataFrame}
)
    @info "Writing curtailment results to $file_path"

    non_empty_dfs = filter(!isempty, curtailment_dfs)
    if isempty(non_empty_dfs)
        @debug "No curtailment results found (no VRE assets in system)"
        return nothing
    end

    curtailment_results = reduce(vcat, non_empty_dfs)

    layout = get_output_layout(system, :Curtailment)
    if layout == "wide"
        curtailment_results = reshape_wide(curtailment_results, :time, :resource_id, :value)
    end

    write_dataframe(file_path, curtailment_results)
    return nothing
end

## Curtailment extraction functions ##

@doc raw"""
    get_optimal_curtailment(
        system::System;
        scaling::Float64=1.0
    )

Get the optimal curtailment values for all VRE assets in a system.

Curtailment at each timestep t is computed as:
    `capacity(e) × availability(e, t) - flow(e, t)`

where capacity is the final installed capacity and flow is the actual generation.

# Arguments
- `system::System`: The system containing VRE assets to analyze
- `scaling::Float64`: Scaling factor for the results (default: 1.0)

# Returns
- `DataFrame`: Temporal curtailment with columns for commodity, zone, resource\_id, resource\_type, component\_id, component\_type, variable, time, value

# Example
```julia
curtailment_df = get_optimal_curtailment(system)
```
"""
function get_optimal_curtailment(system::System; scaling::Float64=1.0)::DataFrame
    @debug " -- Getting optimal curtailment values for the system"

    # Get all VRE assets in the system
    vres_assets = get_assets_sametype(system, VRE)
    if isempty(vres_assets)
        @debug "No VRE assets found in the system to get curtailment values"
        return DataFrame()
    end

    edges, edge_asset_map = edges_with_capacity_variables(vres_assets, return_ids_map=true)

    if isempty(edges)
        @debug "No edges found in the VRE assets $(id.(vres_assets)) to get curtailment values"
        return DataFrame()
    end

    curtailment_df = get_optimal_curtailment(edges, scaling, edge_asset_map)
    curtailment_df[!, (!isa).(eachcol(curtailment_df), Vector{Missing})]
end

function get_optimal_curtailment(
    objs::Vector{<:AbstractEdge},
    scaling::Float64=1.0,
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
)
    reduce(vcat, [get_optimal_curtailment(o, scaling, obj_asset_map) for o in objs])
end

function get_optimal_curtailment(
    obj::AbstractEdge,
    scaling::Float64=1.0,
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
)
    time_axis = time_interval(obj)
    cap_val = Float64(value(capacity(obj)))

    curtailment_values = Float64[
        max(0.0, cap_val * availability(obj, t) - value(flow(obj, t))) * scaling
        for t in time_axis
    ]

    if isempty(obj_asset_map)
        return DataFrame(
            case_name = fill(missing, length(time_axis)),
            commodity = fill(get_commodity_name(obj), length(time_axis)),
            zone = fill(get_zone_name(obj), length(time_axis)),
            resource_id = fill(get_component_id(obj), length(time_axis)),
            component_id = fill(get_component_id(obj), length(time_axis)),
            component_type = fill(get_type(obj), length(time_axis)),
            variable = fill(:curtailment, length(time_axis)),
            year = fill(missing, length(time_axis)),
            time = [t for t in time_axis],
            value = curtailment_values
        )
    else
        return DataFrame(
            case_name = fill(missing, length(time_axis)),
            commodity = fill(get_commodity_name(obj), length(time_axis)),
            zone = fill(get_zone_name(obj), length(time_axis)),
            resource_id = fill(get_resource_id(obj, obj_asset_map), length(time_axis)),
            component_id = fill(get_component_id(obj), length(time_axis)),
            resource_type = fill(get_type(obj_asset_map[id(obj)]), length(time_axis)),
            component_type = fill(get_type(obj), length(time_axis)),
            variable = fill(:curtailment, length(time_axis)),
            year = fill(missing, length(time_axis)),
            time = [t for t in time_axis],
            value = curtailment_values
        )
    end
end
