
# Used in pre_clustering_tdr.jl
function get_extreme_period(DF, GDF, profKey, typeKey, statKey, demand_col_names, solar_col_names, wind_col_names; v=false)
    if v println(profKey," ", typeKey," ", statKey) end
    if typeKey == "Integral"
        if profKey == "Load"
            (stat, group_idx) = get_integral_extreme(GDF, statKey, demand_col_names)
        elseif profKey == "PV"
            (stat, group_idx) = get_integral_extreme(GDF, statKey, solar_col_names)
        elseif profKey == "Wind"
            (stat, group_idx) = get_integral_extreme(GDF, statKey, wind_col_names)
        else
            println(" -- Error: Profile Key ", profKey, " is invalid. Choose `Load', `PV' or `Wind'.")
        end
    elseif typeKey == "Absolute"
        if profKey == "Load"
            (stat, group_idx) = get_absolute_extreme(DF, statKey, demand_col_names)
        elseif profKey == "PV"
            (stat, group_idx) = get_absolute_extreme(DF, statKey, solar_col_names)
        elseif profKey == "Wind"
            (stat, group_idx) = get_absolute_extreme(DF, statKey, wind_col_names)
        else
            println(" -- Error: Profile Key ", profKey, " is invalid. Choose `Load', `PV' or `Wind'.")
        end
   else
       println(" -- Error: Type Key ", typeKey, " is invalid. Choose `Absolute' or `Integral'.")
       stat = 0
       group_idx = 0
   end
    return (stat, group_idx)
end

function get_integral_extreme(GDF, statKey, col_names)
    #println(" → Columns being summed: ", col_names)

    if statKey == "Max"
        (stat, stat_idx) = findmax( sum([GDF[!, Symbol(c)] for c in col_names ]) )
    elseif statKey == "Min"
        (stat, stat_idx) = findmin( sum([GDF[!, Symbol(c)] for c in col_names ]) )
    else
        println(" -- Error: Statistic Key ", statKey, " is invalid. Choose `Max' or `Min'.")
    end
    return (stat, stat_idx)
end

function get_absolute_extreme(DF, statKey, col_names)
    #println(" → Columns being summed: ", col_names)

    if statKey == "Max"
        (stat, stat_idx) = findmax( sum([DF[!, Symbol(c)] for c in col_names ]) )
        group_idx = DF.Group[stat_idx]
    elseif statKey == "Min"
        (stat, stat_idx) = findmin( sum([DF[!, Symbol(c)] for c in col_names ]) )
        group_idx = DF.Group[stat_idx]
    else
        println(" -- Error: Statistic Key ", statKey, " is invalid. Choose `Max' or `Min'.")
    end
    return (stat, group_idx)
end


# Used in run_time_domain_reduction.jl
function to_string_keys(x)
    if x isa Dict
        return Dict(string(k) => to_string_keys(v) for (k,v) in x)
    elseif x isa Vector
        return [to_string_keys(v) for v in x]
    elseif x isa JSON3.Object
        return Dict(string(k) => to_string_keys(v) for (k,v) in pairs(x))
    else
        return x
    end
end

# Used in pre_clustering_tdr.jl
function drop_time_columns!(df)
    if isempty(df)
        return
    end
    dropcols = intersect(names(df), ["Time", "Index", "Time_Index", "Hour", "Datetime"])
    if !isempty(dropcols)
        select!(df, Not(Symbol.(dropcols)))
    end
end

# Used in write_outputs_tdr.jl
function create_reduced_csv(full_path::String, reduced_path::String, M::Vector{Int}, hours_per_period::Int; v=false)
    # Load full-year data
    df_full = CSV.read(full_path, DataFrame)
    total_hours = nrow(df_full)
    ncols = ncol(df_full)

    # Determine file type label based on output name
    filename_lower = lowercase(basename(reduced_path))
    file_type =
        if occursin("demand", filename_lower)
            "Demand"
        elseif occursin("fuel", filename_lower)
            "Fuel Prices"
        elseif occursin("avail", filename_lower)
            "Availability"
        else
            "Time Series"
        end

    # Extract representative periods
    df_reduced_list = DataFrame[]
    for m in M
        start_idx = (m - 1) * hours_per_period + 1
        end_idx   = min(m * hours_per_period, total_hours)
        push!(df_reduced_list, df_full[start_idx:end_idx, :])
    end

    # Concatenate vertically
    df_reduced = vcat(df_reduced_list...)

    # Robustly relabel Time_Index (if present)
    time_col = findfirst(x -> lowercase(string(x)) == "time_index", names(df_reduced))
    if time_col !== nothing
        df_reduced[!, names(df_reduced)[time_col]] = collect(1:nrow(df_reduced))
    elseif "Time" in names(df_reduced)
        df_reduced[!, :Time] = collect(1:nrow(df_reduced))
    end

    # Write reduced CSV
    CSV.write(reduced_path, df_reduced)

    # Log success
    println("Reduced $file_type file written to:", reduced_path)

    if v
        println("   Original hours: ", total_hours,
                " | Reduced hours: ", nrow(df_reduced),
                " | Columns: ", ncols)
        println()
    end
end

# Used in write_outputs_tdr.jl
function write_time_data_json(system_path::String,
                              tdr_output_path::String,
                              period_map_file::String,
                              TimestepsPerRepPeriod::Int,
                              NumberOfSubperiods::Int,
                              TotalHoursModeled::Int;
                              period_idx::Int = 1,
                              v::Bool=false)

    # Load commodities file
    commodities_path = joinpath(system_path, "commodities.json")
    if !isfile(commodities_path)
        error("commodities.json not found at: $commodities_path")
    end

    commodities_json = JSON3.read(open(commodities_path, "r"))
    commodities = String[]

    for entry in commodities_json["commodities"]
        if entry isa String
            push!(commodities, entry)
        elseif haskey(entry, "acts_like")
            push!(commodities, String(entry["acts_like"]))
        elseif haskey(entry, "name")
            push!(commodities, String(entry["name"]))
        end
    end

    commodities = unique(commodities)

    if v
        println("Found commodities: ", commodities)
    end

    # Build time_data dictionary
    HoursPerSubperiod_dict = Dict(c => TimestepsPerRepPeriod for c in commodities)
    HoursPerTimeStep_dict  = Dict(c => 1 for c in commodities)

    time_data = Dict(
        "HoursPerSubperiod"  => HoursPerSubperiod_dict,
        "HoursPerTimeStep"   => HoursPerTimeStep_dict,
        "NumberOfSubperiods" => NumberOfSubperiods,
        "SubPeriodMap"       => Dict(
            "path" => joinpath("system", basename(tdr_output_path), period_map_file)
        ),
        "TotalHoursModeled"  => TotalHoursModeled
    )
    
    # Decide suffix
    suffix = (GLOBAL_NUM_PERIODS[] == 1 ? "" : "_" * string(period_idx))

    # Write JSON
    time_data_filename = "time_data" * suffix * ".json"
    time_data_out_path = joinpath(tdr_output_path, time_data_filename)

    open(time_data_out_path, "w") do io
        JSON3.write(io, time_data; indent=4)
    end

    println("$time_data_filename written to ", time_data_out_path)
    if v
        println("   Number of commodities: ", length(commodities))
        println("   Subperiods: ", NumberOfSubperiods, 
                " | HoursPerRepPeriod: ", TimestepsPerRepPeriod)
        println("   Linked PeriodMap: ", joinpath("system", basename(tdr_output_path), period_map_file))
    end
end


################################ For output-based TDR ################################

function make_subperiod_ranges(T_full::Int, hours_per_subperiod::Int)
    @assert T_full > 0 "T_full must be positive"
    @assert hours_per_subperiod > 0 "hours_per_subperiod must be positive"

    n_sub = ceil(Int, T_full / hours_per_subperiod)
    ranges = Vector{UnitRange{Int}}(undef, n_sub)

    for s in 1:n_sub
        t_start = (s - 1) * hours_per_subperiod + 1
        t_end   = min(s * hours_per_subperiod, T_full)
        ranges[s] = t_start:t_end
    end

    return ranges
end

function get_original_T_full(case_path::AbstractString)::Int
    system_dir = joinpath(case_path, "system")
    timefile = joinpath(system_dir, "time_data.json")

    isfile(timefile) || error("Original time_data.json not found at $(abspath(timefile))")

    # Read raw JSON
    time_data = JSON3.read(open(timefile, "r"))

    # Reuse your existing validator to set TotalHoursModeled if missing
    validate_and_set_default_total_hours_modeled!(time_data)

    T_full = time_data[:TotalHoursModeled]

    println("Original total hours modeled = $T_full")

    return T_full
end

function write_subperiod_results(
    case_sub,
    sp_folder::String,
    sub_cfg,
    out_name::String,
    Zero_Threshold::Float64
)
    # Folder for TDR flow results
    comm_folder = joinpath(sp_folder, "results_for_TDR")
    mkpath(comm_folder)

    df_merged = DataFrame()

    for (commodity, cfg) in sub_cfg
        cfg["Include"] == 1 || continue

        for (asset, toggle) in cfg["Assets"]
            toggle == 1 || continue

            df_asset = get_optimal_flow(
                case_sub.systems[1];
                commodity = string(commodity),
                asset_type = string(asset)
            )
            isempty(df_asset) && continue

            df_wide = reshape_wide(df_asset, :time, :component_id, :value)

            # Write individual file (optional, but you said keep folder outputs)
            out_path = joinpath(comm_folder, "$(commodity)_$(asset).csv")
            CSV.write(out_path, df_wide)

            # Merge into global df
            if isempty(df_merged)
                df_merged = deepcopy(df_wide)
            else
                cols_to_add = setdiff(names(df_wide), names(df_merged))
                df_trim = select(df_wide, [:time; cols_to_add]...)
                df_merged = outerjoin(df_merged, df_trim, on = :time, makeunique = true)
            end
        end
    end

    if isempty(df_merged)
        # still write an empty file so merge step can skip/handle consistently
        df_merged = DataFrame(Time_Index = Int[])
        CSV.write(joinpath(sp_folder, out_name), df_merged)
        return nothing
    end

    rename!(df_merged, :time => :Time_Index)

    for col in names(df_merged)
        col == :Time_Index && continue
        df_merged[abs.(df_merged[!, col]) .< Zero_Threshold, col] .= 0.0
    end

    CSV.write(joinpath(sp_folder, out_name), df_merged)
    return nothing
end



function merge_subperiod_results_to_timeseries(case_path::String, myTDRsetup::Dict; period_idx::Int = 1)

    input_filename  = myTDRsetup["ClusterSubperiodFileName"]
    output_filename = myTDRsetup["ClusterSubperiodFileName"]

    println("Merging all Subperiod_Results.csv files...")

    # Correct base folder
    system_path = joinpath(case_path, "system")
    subperiod_path =
    GLOBAL_NUM_PERIODS[] == 1 ?
        joinpath(case_path, "subperiod_results") :
        joinpath(case_path, "subperiod_results_$(period_idx)")

    isdir(subperiod_path) || error("Folder does not exist: $subperiod_path")

    # Identify sub_XXX folders
    subfolders = filter(f -> occursin(r"^sub_\d{3}$", f), readdir(subperiod_path))
    sort!(subfolders)

    combined_df = DataFrame()

    # Loop and stack results
    for sf in subfolders
        subfile = joinpath(subperiod_path, sf, input_filename)

        if !isfile(subfile)
            @warn "Skipping missing subperiod file: $subfile"
            continue
        end

        df = CSV.read(subfile, DataFrame)

        if nrow(df) == 0
            @warn "Empty subperiod file: $subfile"
            continue
        end

        append!(combined_df, df)
    end

    # Sort by time
    if :Time_Index in names(combined_df)
        sort!(combined_df, :Time_Index)
    end

    # Write final combined file
    name = output_filename  # user TDR setting, e.g., "subperiod_results"
    if GLOBAL_NUM_PERIODS[] == 1
        file = name * ".csv"
    else
        file = name * "_" * string(period_idx) * ".csv"
    end

    out_file = joinpath(system_path, file)

    CSV.write(out_file, combined_df)

    println("Combined stacked file written to: $out_file")

    return out_file
end


"""
    write_raw_subperiod_results(case_sub, sp_folder)

Writes full, unfiltered MacroEnergy results for this subperiod into:

    sub_XXX/full_results/

This includes:
  • capacity.csv
  • flows.csv
  • duals (only if DualExportsEnabled = true)
  • time_weights.csv

Arguments:
  - case_sub  :: the subperiod case object returned by build_subperiod_case
  - sp_folder :: folder for this subperiod (e.g., "sub_003")
"""
function write_subperiod_results(case_sub, sp_folder::String)

    # Where to write raw results
    raw_dir = joinpath(sp_folder, "results")
    mkpath(raw_dir)

    system_sub = case_sub.systems[1]

    # Capacity results
    write_capacity(joinpath(raw_dir, "capacity.csv"), system_sub)

    # Flow results (all commodities, all assets)
    write_flow(joinpath(raw_dir, "flows.csv"), system_sub)

    # Duals (if enabled)
    if system_sub.settings.DualExportsEnabled
        write_duals(raw_dir, system_sub, 1.0)
    end

    # Time weights
    write_time_weights(raw_dir, system_sub)
end


function write_subperiod_availability(system, outdir::AbstractString)
    # Collect availability for all edges that actually have a time series
    rows = DataFrame(time = Int[], component_id = Symbol[], availability = Float64[])

    edges, edge_asset_map = get_edges(system, return_ids_map = true)

    for e in edges
        # raw availability vector
        a_vec = availability(e)

        # Skip trivial/default ones: empty or single value (always 1 or a constant)
        if isempty(a_vec) || length(a_vec) == 1
            continue
        end

        t_axis = collect(time_interval(e))

        # Safety: skip if availability too short (shouldn't happen, but just in case)
        if maximum(t_axis) > length(a_vec)
            @warn "Availability length mismatch for edge $(id(e)), skipping in debug export"
            continue
        end

        vals = [availability(e, t) for t in t_axis]

        df_e = DataFrame(
            time         = t_axis,
            component_id = fill(get_component_id(e), length(t_axis)),
            availability = vals,
        )

        append!(rows, df_e)
    end

    if nrow(rows) == 0
        @warn "write_subperiod_availability: no edges with non-trivial availability found."
        return
    end

    # Reshape to wide format: one column per component_id
    df_wide = reshape_wide(rows, :time, :component_id, :availability)
    sort!(df_wide, :time)

    mkpath(outdir)
    CSV.write(joinpath(outdir, "subperiod_availability.csv"), df_wide)
end

function write_subperiod_demand(system, outdir::AbstractString)
    rows = DataFrame(time = Int[], node_id = Symbol[], demand = Float64[])

    nodes = get_nodes(system)   # MacroEnergy helper (same as used internally)

    for n in nodes
        d_vec = demand(n)

        # Skip trivial/no demand
        if isempty(d_vec) || length(d_vec) == 1
            continue
        end

        t_axis = collect(time_interval(n))

        # Safety check
        if maximum(t_axis) > length(d_vec)
            @warn "Demand length mismatch for node $(id(n)), skipping."
            continue
        end

        vals = [demand(n, t) for t in t_axis]

        df_n = DataFrame(
            time    = t_axis,
            node_id = fill(id(n), length(t_axis)),
            demand  = vals
        )

        append!(rows, df_n)
    end

    if nrow(rows) == 0
        @warn "write_subperiod_demand: no nodes with non-trivial demand found."
        return
    end

    df_wide = reshape_wide(rows, :time, :node_id, :demand)
    sort!(df_wide, :time)

    mkpath(outdir)
    CSV.write(joinpath(outdir, "subperiod_demand.csv"), df_wide)
end

"""
Clear all policy-related constraints and bookkeeping from a Node.
Safe to call on any object; non-Nodes are ignored.
"""
function clear_policy!(n)
    if !(n isa Node)
        return
    end

    # Remove policy-type constraints
    n.constraints = filter(ct ->
        !(ct isa CO2CapConstraint ||
          ct isa CO2StorageConstraint ||
          ct isa PolicyConstraint),
        n.constraints
    )

    # Clear policy bookkeeping
    empty!(n.rhs_policy)
    empty!(n.price_unmet_policy)
    empty!(n.policy_budgeting_constraints)
    empty!(n.policy_budgeting_vars)
    empty!(n.policy_slack_vars)

    return
end


"""
Disable all policy constraints (CO₂ caps, storage, PolicyConstraint)
for every Node in the system.

Safe even when called before Node or System are defined in module load order.
"""
function disable_policy_constraints!(system)
    # System.locations contains Nodes and Locations
    for loc in system.locations
        if loc isa Node
            clear_policy!(loc)

        elseif loc isa Location
            for n in values(loc.nodes)
                clear_policy!(n)
            end
        end
    end

    return
end


function write_subperiods_solve_time(case_path::String, subperiods_solve_time; period_idx::Int = 1)
    #Write subperiod solve time for each period (stage)
    runtime_df = DataFrame(
        Subperiod_Runtime = [subperiods_solve_time],
    )
    system_path = joinpath(case_path, "system")

    name = "subperiod_runtime"
    if GLOBAL_NUM_PERIODS[] == 1
        file = name * ".csv"
    else
        file = name * "_" * string(period_idx) * ".csv"
    end

    out_file = joinpath(system_path, file)

    CSV.write(out_file, runtime_df)
end
