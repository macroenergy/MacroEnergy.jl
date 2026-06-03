"""
Full time series reconstruction — expands representative-period outputs back to
TotalHoursModeled hours (typically 8760) using the SubPeriodMap.

Outputs are written to a `full_time_series/` subdirectory inside the results directory.
Only runs when the system uses time-domain reduction (i.e., a non-identity SubPeriodMap),
and the settings option `WriteFullTimeseries` is `true`. Skips with a warning otherwise.
"""

"""
    write_full_timeseries(results_dir::AbstractString, system::System, scaling::Float64, var_cost_discount::Float64=1.0)

Write all time-series outputs expanded to `TotalHoursModeled` hours into a
`full_time_series/` subdirectory of `results_dir`.

Note: for long format outputs, the full time series files are written in 
compressed `.csv.gz` format.

When `DualExportsEnabled` is set in the system settings, balance constraint duals
are also written, scaled by `var_cost_discount`.

Skips with a warning if the system does not use time-domain reduction.
"""
function write_full_timeseries(
    results_dir::AbstractString,
    system::System,
    scaling::Float64,
    var_cost_discount::Float64=1.0
)
    if !has_tdr(system)
        @warn "Skipping full time series reconstruction: no period map detected."
        return nothing
    end

    fullts_dir = mkpath(joinpath(results_dir, "full_time_series"))

    # Use .csv.gz for long format (files can be very large at 8760 rows × many components)
    file_ext(var::Symbol) = get_output_layout(system, var) == "long" ? ".csv.gz" : ".csv"

    write_flow_full_timeseries(joinpath(fullts_dir, "flows$(file_ext(:Flow))"), system, scaling)
    write_non_served_demand_full_timeseries(joinpath(fullts_dir, "non_served_demand$(file_ext(:NonServedDemand))"), system, scaling)
    write_storage_level_full_timeseries(joinpath(fullts_dir, "storage_level$(file_ext(:StorageLevel))"), system, scaling)
    write_curtailment_full_timeseries(joinpath(fullts_dir, "curtailment$(file_ext(:Curtailment))"), system, scaling)

    # Balance duals (only when dual exports are enabled)
    if system.settings.DualExportsEnabled
        write_balance_duals_full_timeseries(joinpath(fullts_dir, "balance_duals.csv"), system, var_cost_discount * scaling)
    end

    return nothing
end

"""
    reconstruct_timeseries(vals::Vector{Float64}, timedata::TimeData) -> Vector{Float64}

Expand a vector of representative-period values to all `TotalHoursModeled` hours by
repeating each representative sub-period's values for every full-year period it represents.

If the period map covers fewer hours than `TotalHoursModeled` (e.g. 52×168 = 8736 < 8760),
the remaining hours are filled by repeating values from the representative period that
corresponds to the last calendar sub-period, and a warning is logged once.

# Arguments
- `vals::Vector{Float64}`: Time series values for each representative period, ordered by `subperiod_indices`.
- `timedata::TimeData`: TimeData object containing the sub-period map and related info.

# Returns
- `Vector{Float64}`: Full time series values expanded to `TotalHoursModeled` hours.
"""
function reconstruct_timeseries(vals::Vector{Float64}, timedata::TimeData)
    subperiod_map     = timedata.subperiod_map
    subperiods        = timedata.subperiods
    subperiod_indices = timedata.subperiod_indices
    total_hours       = timedata.total_hours_modeled
    hours_per_subperiod = length(first(subperiods)) # assumes all subperiods have the same number of hours

    # Precompute rep-period-id → position lookup
    rep_idx_lookup = Dict(subperiod_indices[i] => i for i in eachindex(subperiod_indices))

    sorted_keys = sort(collect(keys(subperiod_map)))
    n_mapped = length(sorted_keys) * hours_per_subperiod
    if n_mapped > total_hours
        @warn "Period map covers $n_mapped hours but TotalHoursModeled is only $total_hours. Output will be truncated."
    end
    result = Vector{Float64}(undef, total_hours)

    offset = 0
    rep_idx = 0
    for p in sorted_keys
        offset + hours_per_subperiod > total_hours && break # stop if we've filled the result array up to TotalHoursModeled
        rep_idx = rep_idx_lookup[subperiod_map[p]]
        copyto!(result, offset + 1, vals, first(subperiods[rep_idx]), hours_per_subperiod)
        offset += hours_per_subperiod
    end

    last_rep_idx = rep_idx  # in case we need to pad with the last representative period
    if offset < total_hours
        n_missing = total_hours - offset
        @info "Period map covers $offset hours but TotalHoursModeled is $total_hours. " *
              "Padding the remaining $n_missing hours by repeating the last sub-period." maxlog=1
        last_range = subperiods[last_rep_idx]
        last_len = length(last_range)
        while offset < total_hours
            chunk = min(last_len, total_hours - offset)
            copyto!(result, offset + 1, vals, first(last_range), chunk)
            offset += chunk
        end
    end

    return result
end

"""
    has_tdr(system::System) -> Bool

Return `true` if the system uses time-domain reduction (i.e., at least one TimeData in the System
has a non-identity SubPeriodMap where some full-year periods map to different rep periods).
"""
function has_tdr(system::System)
    isempty(system.time_data) && return false
    return any(values(system.time_data)) do time_data
        # Check if subperiod_map is non-identity
        any(k != v for (k, v) in time_data.subperiod_map)
    end
end

# ---------------------------------------------------------------------------
# Flow
# ---------------------------------------------------------------------------

function write_flow_full_timeseries(file_path::AbstractString, system::System, scaling::Float64)
    @info "Writing full time series flow results to $file_path"

    flow_results = get_full_timeseries_flow(system, scaling)

    if isempty(flow_results)
        @debug "No flow results found"
        return nothing
    end

    layout = get_output_layout(system, :Flow)
    if layout == "wide"
        flow_results = reshape_wide(flow_results, :time, :component_id, :value)
    end

    write_dataframe(file_path, flow_results)
    return nothing
end

function get_full_timeseries_flow(system::System, scaling::Float64)
    edges, edge_asset_map = get_edges(system, return_ids_map=true)
    isempty(edges) && return DataFrame()
    flow_df = reduce(vcat, [_full_ts_flow(obj, scaling, edge_asset_map) for obj in edges])
    flow_df[!, (!isa).(eachcol(flow_df), Vector{Missing})]
end

function _full_ts_flow(obj::AbstractEdge, scaling::Float64, obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}})
    time_axis = time_interval(obj)
    flow_sign = get_flow_sign(obj)
    vals = Float64[value(flow(obj, t)) * flow_sign for t in time_axis]
    full_vals = reconstruct_timeseries(vals, obj.timedata)
    n = length(full_vals)

    return DataFrame(
        case_name      = fill(missing, n),
        commodity      = fill(get_commodity_name(obj), n),
        node_in        = fill(get_node_in(obj), n),
        node_out       = fill(get_node_out(obj), n),
        resource_id    = fill(get_resource_id(obj, obj_asset_map), n),
        component_id   = fill(get_component_id(obj), n),
        resource_type  = fill(get_type(obj_asset_map[id(obj)]), n),
        component_type = fill(get_type(obj), n),
        variable       = fill(:flow, n),
        year           = fill(missing, n),
        time           = 1:n,
        value          = full_vals * scaling
    )
end

# ---------------------------------------------------------------------------
# Non-served demand
# ---------------------------------------------------------------------------

function write_non_served_demand_full_timeseries(file_path::AbstractString, system::System, scaling::Float64)
    @info "Writing full time series non-served demand results to $file_path"

    nsd_results = get_full_timeseries_non_served_demand(system, scaling)

    if isempty(nsd_results)
        @debug "No non-served demand results found (no nodes have NSD variables)"
        return nothing
    end

    layout = get_output_layout(system, :NonServedDemand)
    if layout == "wide"
        nsd_results[!, :component_id_seg] = string.(nsd_results.component_id) .* "_seg" .* string.(nsd_results.segment)
        nsd_results = reshape_wide(nsd_results, :time, :component_id_seg, :value)
    end

    write_dataframe(file_path, nsd_results)
    return nothing
end

function get_full_timeseries_non_served_demand(system::System, scaling::Float64)
    nodes_with_nsd = filter(n -> !isempty(non_served_demand(n)), get_nodes(system))
    isempty(nodes_with_nsd) && return DataFrame()
    nsd_df = reduce(vcat, [_full_ts_nsd(n, scaling) for n in nodes_with_nsd])
    nsd_df[!, (!isa).(eachcol(nsd_df), Vector{Missing})]
end

function _full_ts_nsd(node::Node, scaling::Float64)
    time_axis = time_interval(node)
    num_segments = length(segments_non_served_demand(node))

    rows = DataFrame[]
    for s in 1:num_segments
        vals = Float64[value(non_served_demand(node, s, t)) for t in time_axis]
        full_vals = reconstruct_timeseries(vals, node.timedata)
        n = length(full_vals)
        push!(rows, DataFrame(
            case_name      = fill(missing, n),
            commodity      = fill(get_commodity_name(node), n),
            zone           = fill(get_zone_name(node), n),
            component_id   = fill(id(node), n),
            component_type = fill(get_type(node), n),
            variable       = fill(:non_served_demand, n),
            year           = fill(missing, n),
            segment        = fill(s, n),
            time           = 1:n,
            value          = full_vals * scaling
        ))
    end
    reduce(vcat, rows)
end

# ---------------------------------------------------------------------------
# Storage level
# ---------------------------------------------------------------------------

function write_storage_level_full_timeseries(file_path::AbstractString, system::System, scaling::Float64)
    @info "Writing full time series storage level results to $file_path"

    storage_results = get_full_timeseries_storage_level(system, scaling)

    if isempty(storage_results)
        @debug "No storage level results found"
        return nothing
    end

    layout = get_output_layout(system, :StorageLevel)
    if layout == "wide"
        storage_results = reshape_wide(storage_results, :time, :component_id, :value)
    end

    write_dataframe(file_path, storage_results)
    return nothing
end

function get_full_timeseries_storage_level(system::System, scaling::Float64)
    storages, storage_asset_map = get_storages(system, return_ids_map=true)
    isempty(storages) && return DataFrame()
    non_empty = filter(s -> !isempty(time_interval(s)), storages)
    isempty(non_empty) && return DataFrame()
    storage_df = reduce(vcat, [_full_ts_storage(s, scaling, storage_asset_map) for s in non_empty])
    storage_df[!, (!isa).(eachcol(storage_df), Vector{Missing})]
end

function _full_ts_storage(storage::AbstractStorage, scaling::Float64, storage_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}})
    time_axis = time_interval(storage)
    vals = Float64[value(storage_level(storage, t)) for t in time_axis]
    full_vals = reconstruct_timeseries(vals, storage.timedata)
    n = length(full_vals)

    return DataFrame(
        case_name      = fill(missing, n),
        commodity      = fill(get_commodity_name(storage), n),
        zone           = fill(get_zone_name(storage), n),
        resource_id    = fill(get_resource_id(storage, storage_asset_map), n),
        component_id   = fill(id(storage), n),
        resource_type  = fill(get_type(storage_asset_map[id(storage)]), n),
        component_type = fill(get_type(storage), n),
        variable       = fill(:storage_level, n),
        year           = fill(missing, n),
        time           = 1:n,
        value          = full_vals * scaling
    )
end

# ---------------------------------------------------------------------------
# Curtailment
# ---------------------------------------------------------------------------

function write_curtailment_full_timeseries(file_path::AbstractString, system::System, scaling::Float64)
    @info "Writing full time series curtailment results to $file_path"

    curtailment_results = get_full_timeseries_curtailment(system, scaling)

    if isempty(curtailment_results)
        @debug "No curtailment results found (no VRE assets in system)"
        return nothing
    end

    layout = get_output_layout(system, :Curtailment)
    if layout == "wide"
        curtailment_results = reshape_wide(curtailment_results, :time, :resource_id, :value)
    end

    write_dataframe(file_path, curtailment_results)
    return nothing
end

function get_full_timeseries_curtailment(system::System, scaling::Float64)
    vres_assets = get_assets_sametype(system, VRE)
    isempty(vres_assets) && return DataFrame()
    edges, edge_asset_map = edges_with_capacity_variables(vres_assets, return_ids_map=true)
    isempty(edges) && return DataFrame()
    curtailment_df = reduce(vcat, [_full_ts_curtailment(obj, scaling, edge_asset_map) for obj in edges])
    curtailment_df[!, (!isa).(eachcol(curtailment_df), Vector{Missing})]
end

function _full_ts_curtailment(obj::AbstractEdge, scaling::Float64, obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}})
    time_axis = time_interval(obj)
    cap_val = Float64(value(capacity(obj)))
    vals = Float64[max(0.0, cap_val * availability(obj, t) - value(flow(obj, t))) for t in time_axis]
    full_vals = reconstruct_timeseries(vals, obj.timedata)
    n = length(full_vals)

    return DataFrame(
        case_name      = fill(missing, n),
        commodity      = fill(get_commodity_name(obj), n),
        zone           = fill(get_zone_name(obj), n),
        resource_id    = fill(get_resource_id(obj, obj_asset_map), n),
        component_id   = fill(get_component_id(obj), n),
        resource_type  = fill(get_type(obj_asset_map[id(obj)]), n),
        component_type = fill(get_type(obj), n),
        variable       = fill(:curtailment, n),
        year           = fill(missing, n),
        time           = 1:n,
        value          = full_vals * scaling
    )
end

# ===========================================================================
# Benders dispatch — reconstruct from pre-collected subproblem DataFrames
# ===========================================================================

"""
    write_full_timeseries(results_dir, system, flow_dfs, nsd_dfs, storage_dfs, curtailment_dfs, scaling::Float64; var_cost_discount::Float64=1.0)

Benders version: write all time-series outputs expanded to `TotalHoursModeled` hours,
reconstructing from per-representative-period subproblem DataFrames.

When `DualExportsEnabled` is set in the system settings, balance constraint duals are
also written, scaled by `var_cost_discount`.
"""
function write_full_timeseries(
    results_dir::AbstractString, system::System,
    flow_dfs::Vector{DataFrame}, nsd_dfs::Vector{DataFrame},
    storage_dfs::Vector{DataFrame}, curtailment_dfs::Vector{DataFrame},
    scaling::Float64;
    var_cost_discount::Float64=1.0
)
    if !has_tdr(system)
        @warn "Skipping full time series reconstruction: no period map detected."
        return nothing
    end

    fullts_dir = mkpath(joinpath(results_dir, "full_time_series"))
    file_ext(var::Symbol) = get_output_layout(system, var) == "long" ? ".csv.gz" : ".csv"

    write_flow_full_timeseries(joinpath(fullts_dir, "flows$(file_ext(:Flow))"), system, flow_dfs, scaling)
    write_non_served_demand_full_timeseries(joinpath(fullts_dir, "non_served_demand$(file_ext(:NonServedDemand))"), system, nsd_dfs, scaling)
    write_storage_level_full_timeseries(joinpath(fullts_dir, "storage_level$(file_ext(:StorageLevel))"), system, storage_dfs, scaling)
    write_curtailment_full_timeseries(joinpath(fullts_dir, "curtailment$(file_ext(:Curtailment))"), system, curtailment_dfs, scaling)

    # Balance duals (only when dual exports are enabled)
    if system.settings.DualExportsEnabled
        write_balance_duals_full_timeseries(joinpath(fullts_dir, "balance_duals.csv"), system, scaling * var_cost_discount)
    end

    return nothing
end

"""
    reconstruct_benders_variable(dfs, timedata_lookup; group_cols=[:component_id])

Reconstruct full time series from per-representative-period Benders DataFrames.

Each element of `dfs` contains operational results for one representative period (same
ordering as `subperiod_indices`). Values are concatenated across rep periods for each
component group, then expanded to `TotalHoursModeled` hours via `reconstruct_timeseries`.

# Arguments
- `dfs::Vector{DataFrame}`: One DataFrame per representative period
- `timedata_lookup::Dict{Symbol, <:TimeData}`: Component ID → TimeData mapping
- `group_cols::Vector{Symbol}`: Columns that identify a unique time series
  (e.g., `[:component_id]` for flows, `[:component_id, :segment]` for NSD)
"""
function reconstruct_benders_variable(
    dfs::Vector{DataFrame},
    timedata_lookup::Dict{Symbol, <:TimeData},
    scaling::Float64;
    group_cols::Vector{Symbol} = [:component_id]
)
    non_empty_dfs = filter(!isempty, dfs)
    isempty(non_empty_dfs) && return DataFrame()

    # Combine all rep-period DataFrames and group by component (+ segment for NSD)
    combined_df = reduce(vcat, non_empty_dfs)
    groups = groupby(combined_df, group_cols)

    result_dfs = DataFrame[]
    for group in groups
        component_id = first(group.component_id)
        haskey(timedata_lookup, component_id) || continue

        # Sort by time to ensure correct rep-period ordering, then reconstruct
        sorted_group = sort(DataFrame(group), :time)
        values_by_time = convert(Vector{Float64}, sorted_group.value)
        full_timeseries = reconstruct_timeseries(values_by_time, timedata_lookup[component_id])
        n_hours = length(full_timeseries)

        # Copy metadata columns from first row; replace :time and :value with expanded data
        metadata = first(eachrow(group))
        out = DataFrame(
            [col => (col == "time" ? (1:n_hours) :
                     col == "value" ? full_timeseries :
                     fill(metadata[col], n_hours))
             for col in names(group)]
        )
        push!(result_dfs, out)
    end

    isempty(result_dfs) && return DataFrame()
    reduce(vcat, result_dfs)
end

# ---------------------------------------------------------------------------
# Benders: Flow
# ---------------------------------------------------------------------------

function write_flow_full_timeseries(file_path::AbstractString, system::System, flow_dfs::Vector{DataFrame}, scaling::Float64)
    @info "Writing full time series flow results to $file_path"

    edges = get_edges(system)
    timedata_lookup = Dict(get_component_id(e) => e.timedata for e in edges)

    flow_results = reconstruct_benders_variable(flow_dfs, timedata_lookup, scaling)
    if isempty(flow_results)
        @debug "No flow results found"
        return nothing
    end

    layout = get_output_layout(system, :Flow)
    if layout == "wide"
        flow_results = reshape_wide(flow_results, :time, :component_id, :value)
    end

    write_dataframe(file_path, flow_results)
    return nothing
end

# ---------------------------------------------------------------------------
# Benders: Non-served demand
# ---------------------------------------------------------------------------

function write_non_served_demand_full_timeseries(file_path::AbstractString, system::System, nsd_dfs::Vector{DataFrame}, scaling::Float64)
    @info "Writing full time series non-served demand results to $file_path"

    nodes = get_nodes(system)
    timedata_lookup = Dict(id(n) => n.timedata for n in nodes)

    nsd_results = reconstruct_benders_variable(nsd_dfs, timedata_lookup, scaling; group_cols=[:component_id, :segment])
    if isempty(nsd_results)
        @debug "No non-served demand results found (no nodes have NSD variables)"
        return nothing
    end

    layout = get_output_layout(system, :NonServedDemand)
    if layout == "wide"
        nsd_results[!, :component_id_seg] = string.(nsd_results.component_id) .* "_seg" .* string.(nsd_results.segment)
        nsd_results = reshape_wide(nsd_results, :time, :component_id_seg, :value)
    end

    write_dataframe(file_path, nsd_results)
    return nothing
end

# ---------------------------------------------------------------------------
# Benders: Storage level
# ---------------------------------------------------------------------------

function write_storage_level_full_timeseries(file_path::AbstractString, system::System, storage_dfs::Vector{DataFrame}, scaling::Float64)
    @info "Writing full time series storage level results to $file_path"

    storages = get_storages(system)
    timedata_lookup = Dict(id(s) => s.timedata for s in storages)

    storage_results = reconstruct_benders_variable(storage_dfs, timedata_lookup, scaling)
    if isempty(storage_results)
        @debug "No storage level results found"
        return nothing
    end

    layout = get_output_layout(system, :StorageLevel)
    if layout == "wide"
        storage_results = reshape_wide(storage_results, :time, :component_id, :value)
    end

    write_dataframe(file_path, storage_results)
    return nothing
end

# ---------------------------------------------------------------------------
# Benders: Curtailment
# ---------------------------------------------------------------------------

function write_curtailment_full_timeseries(file_path::AbstractString, system::System, curtailment_dfs::Vector{DataFrame}, scaling::Float64)
    @info "Writing full time series curtailment results to $file_path"

    edges = get_edges(system)
    timedata_lookup = Dict(get_component_id(e) => e.timedata for e in edges)

    curtailment_results = reconstruct_benders_variable(curtailment_dfs, timedata_lookup, scaling)
    if isempty(curtailment_results)
        @debug "No curtailment results found (no VRE assets in system)"
        return nothing
    end

    # Remove columns that are all missing
    curtailment_results = curtailment_results[!, (!isa).(eachcol(curtailment_results), Vector{Missing})]

    layout = get_output_layout(system, :Curtailment)
    if layout == "wide"
        curtailment_results = reshape_wide(curtailment_results, :time, :resource_id, :value)
    end

    write_dataframe(file_path, curtailment_results)
    return nothing
end

# ---------------------------------------------------------------------------
# Balance duals
# ---------------------------------------------------------------------------

"""
    write_balance_duals_full_timeseries(file_path::AbstractString, system::System, scaling::Float64)

Write balance constraint duals expanded to `TotalHoursModeled` hours.

Requires the model to have been solved so that dual values are available.
"""
function write_balance_duals_full_timeseries(
    file_path::AbstractString,
    system::System,
    scaling::Float64
)
    if !has_tdr(system)
        return nothing
    end

    @info "Writing full time series balance duals to $file_path"

    duals, node_ids, timedata_vec = _extract_balance_duals(system, scaling; with_timedata=true)
    isempty(duals) && return nothing

    full_duals = [reconstruct_timeseries(d, td) for (d, td) in zip(duals, timedata_vec)]
    
    df = DataFrame(full_duals, node_ids, copycols=false)
    write_dataframe(file_path, df)
    return nothing
end
