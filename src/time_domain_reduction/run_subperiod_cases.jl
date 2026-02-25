using Distributed

"""
Compute subperiod results as a DataFrame (no file I/O).

Returns a DataFrame with all flows for the configured assets,
ready to be stacked with other subperiods.
"""
function compute_subperiod_results_df(
    case_sub,
    sub_cfg,
    Zero_Threshold::Float64
)
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
        return DataFrame(Time_Index = Int[])
    end

    rename!(df_merged, :time => :Time_Index)

    # Filter out near-zero values
    for col in names(df_merged)
        col == "Time_Index" && continue
        df_merged[!, col] = [abs(v) < Zero_Threshold ? 0.0 : v for v in df_merged[!, col]]
    end

    return df_merged
end


"""
Solve ONE subperiod on worker and return DataFrame.
Optionally write debug files if v=true.
"""
function solve_one_subperiod_worker_df(
    subperiod_data::Dict,
    optimizer::DataType,
    optimizer_env,
    optimizer_attributes,
    Zero_Threshold::Float64,
    sub_cfg,
    out_name::String,
    sub_results_dir::String;
    v::Bool=false
)
    sp = subperiod_data[:sp]
    case_sub = subperiod_data[:case_sub]

    # Build optimizer locally on this process
    opt = create_optimizer(optimizer, optimizer_env, optimizer_attributes)

    # Solve this subperiod
    solve_start = time()
    solve_case(case_sub, opt, Monolithic())
    solve_time = time() - solve_start
    @info "Subperiod $sp solved in $(round(solve_time; digits=2)) seconds on worker pid=$(myid())"

    # Compute results as DataFrame (no file I/O)
    df_result = compute_subperiod_results_df(case_sub, sub_cfg, Zero_Threshold)

    # Write debug files if v=true
    if v
        sp_folder = joinpath(sub_results_dir, "sub_$(lpad(string(sp), 3, '0'))")
        mkpath(sp_folder)

        # Write raw results (capacity, flows, duals)
        write_subperiod_results(case_sub, sp_folder)

        # Write filtered TDR results
        write_subperiod_results(case_sub, sp_folder, sub_cfg, out_name, Zero_Threshold)

        # Write availability and demand debug files
        system_sub = case_sub.systems[1]
        write_subperiod_availability(system_sub, sp_folder)
        write_subperiod_demand(system_sub, sp_folder)
    end

    return (sp = sp, df = df_result)
end


"""
Solve local subperiods on worker and return DataFrames.
"""
function solve_local_subperiods_df(
    subperiod_data_local::Vector{Dict},
    optimizer::DataType,
    optimizer_env,
    optimizer_attributes,
    Zero_Threshold::Float64,
    sub_cfg,
    out_name::String,
    sub_results_dir::String;
    v::Bool=false
)
    results = []
    for sp_data in subperiod_data_local
        result = solve_one_subperiod_worker_df(
            sp_data,
            optimizer, optimizer_env, optimizer_attributes,
            Zero_Threshold,
            sub_cfg,
            out_name,
            sub_results_dir;
            v=v
        )
        push!(results, result)
    end
    return results
end


function run_subperiod_cases(
    case_path::String,
    optimizer::DataType,
    optimizer_env,
    optimizer_attributes,
    mysetup::Dict;
    num_periods::Int = 1,
    v::Bool = false
)
    println()
    println("=== Output-based TDR: Running subperiod CEMs ===")

    # ============================================================
    # 1. Load settings
    # ============================================================
    TimestepsPerRepPeriod      = mysetup["TimestepsPerRepPeriod"]
    SubperiodPolicyConstraints = mysetup["SubperiodPolicyConstraints"]
    sub_cfg                    = mysetup["SubperiodResults"]["Commodities"]
    Zero_Threshold = Float64(mysetup["Zero_Threshold"])

    # Optional distributed toggle + worker count
    use_distributed = get(mysetup, "DistributedSubperiodCases", 0) == 1
    nworkers_req    = get(mysetup, "NumSubperiodWorkers", 0)  # 0 => auto

    # Validate that at least one commodity+asset is included
    has_valid_output = false
    for (_, cfg) in sub_cfg
        cfg["Include"] == 1 || continue
        for (_, toggle) in cfg["Assets"]
            if toggle == 1
                has_valid_output = true
                break
            end
        end
        has_valid_output && break
    end

    if !has_valid_output
        error("""
        No subperiod outputs selected!
        In TDR_settings.json, at least one commodity must have `"Include": 1`
        AND at least one of its assets must also have `"Include": 1`.
        """)
    end

    # ============================================================
    # 2. Solve subperiods
    # ============================================================
    GLOBAL_TDR_FLAG[] = 0
    @info "Include subperiod cases results in TDR"

    system_path = joinpath(case_path, "system")

    for s in 1:num_periods
        base_name = mysetup["ClusterSubperiodFileName"]
        file = (GLOBAL_NUM_PERIODS[] == 1) ? base_name * ".csv" : base_name * "_" * string(s) * ".csv"
        subperiod_results_file = joinpath(system_path, file)

        if isfile(subperiod_results_file)
            @info "Subperiod results already exist for period $s, skipping subperiod runs"
            continue
        else
            @info "Generating subperiod results for period $s"
        end

        T_full = get_original_T_full(case_path)
        ranges_all = make_subperiod_ranges(T_full, TimestepsPerRepPeriod)
        ranges = [r for r in ranges_all if length(r) == TimestepsPerRepPeriod]
        num_sub = length(ranges)

        println("Running total of $num_sub complete subperiods (dropped $(length(ranges_all) - num_sub) incomplete)")

        weight_per_hour = T_full / TimestepsPerRepPeriod
        subperiods_solve_start = time()

        # Create subperiod results folder for debug outputs if v=true
        if v
            sub_results_dir = (GLOBAL_NUM_PERIODS[] == 1) ?
                joinpath(case_path, "subperiod_results") :
                joinpath(case_path, "subperiod_results_$(s)")
            mkpath(sub_results_dir)
        end

        if !use_distributed || num_sub == 0
            # SERIAL - DataFrame approach (no folder creation)
            @info "Running subperiod cases in SERIAL mode"

            full_case = load_case(case_path; lazy_load=true)
            opt = create_optimizer(optimizer, optimizer_env, optimizer_attributes)

            if length(full_case.systems) > 1
                case_s = deepcopy(full_case)
                case_s.systems = [full_case.systems[s]]
            else
                case_s = full_case
            end

            # Collect results as DataFrames (no file writes)
            all_results = []

            for sp in 1:num_sub
                t_range = ranges[sp]
                println("Running $sp / $num_sub subperiods t = $t_range\n")

                case_sub = deepcopy(case_s)

                if SubperiodPolicyConstraints == 0
                    println("Disabling all policy constraints for subperiod cases.\n")
                    for sys in case_sub.systems
                        disable_policy_constraints!(sys)
                    end
                end

                for sys in case_sub.systems
                    for c in keys(sys.time_data)
                        td = sys.time_data[c]
                        td.time_interval = t_range
                        td.subperiods = [t_range]
                        td.subperiod_indices = [1]
                        td.subperiod_weights = Dict(1 => weight_per_hour)
                        td.subperiod_map = Dict(t => 1 for t in t_range)
                        td.period_index = s
                    end
                end

                solve_start = time()
                solve_case(case_sub, opt, Monolithic())
                solve_time = time() - solve_start
                println("Subperiod $sp solved in $(round(solve_time; digits=2)) seconds")

                # Compute results as DataFrame (no file I/O)
                df_result = compute_subperiod_results_df(case_sub, sub_cfg, Zero_Threshold)
                push!(all_results, (sp = sp, df = df_result))

                # Write debug files if v=true
                if v
                    sp_folder = joinpath(sub_results_dir, "sub_$(lpad(string(sp), 3, '0'))")
                    mkpath(sp_folder)

                    # Write raw results (capacity, flows, duals)
                    write_subperiod_results(case_sub, sp_folder)

                    # Write filtered TDR results
                    write_subperiod_results(case_sub, sp_folder, sub_cfg, mysetup["ClusterSubperiodFileName"], Zero_Threshold)

                    # Write availability and demand debug files
                    system_sub = case_sub.systems[1]
                    write_subperiod_availability(system_sub, sp_folder)
                    write_subperiod_demand(system_sub, sp_folder)
                end
            end

            # Stack DataFrames in order
            @info "Stacking $(length(all_results)) subperiod results"
            combined_df = DataFrame()
            for result in all_results
                if nrow(result.df) > 0
                    append!(combined_df, result.df)
                end
            end

            # Sort by time index
            if nrow(combined_df) > 0 && :Time_Index in names(combined_df)
                sort!(combined_df, :Time_Index)
            end

            # Write final merged file
            system_path = joinpath(case_path, "system")
            base_name = mysetup["ClusterSubperiodFileName"]
            file = (GLOBAL_NUM_PERIODS[] == 1) ? base_name * ".csv" : base_name * "_" * string(s) * ".csv"
            out_file = joinpath(system_path, file)
            CSV.write(out_file, combined_df)
            @info "Combined stacked file written to: $out_file"

        else
            # DISTRIBUTED - following Benders pattern
            @info "Running subperiod cases in DISTRIBUTED mode"

            nworkers_target = nworkers_req > 0 ? min(nworkers_req, num_sub) : min(num_sub, Sys.CPU_THREADS)
            start_distributed_processes!(nworkers_target, case_path)

            pids = workers()
            np = length(pids)
            @info "Dispatching $num_sub subperiods across $np workers"

            # MASTER: Load case once and prepare all subperiod cases
            @info "Master process: Loading case and preparing $num_sub subperiod cases"
            prep_start = time()

            full_case = load_case(case_path; lazy_load=true)

            # Slice correct period if multi-period
            if length(full_case.systems) > 1
                case_s = deepcopy(full_case)
                case_s.systems = [full_case.systems[s]]
            else
                case_s = full_case
            end

            # Create subperiod metadata (ranges, parameters) on master
            subperiod_metadata = Vector{Dict}(undef, num_sub)

            for sp in 1:num_sub
                t_range = ranges[sp]

                # Skip incomplete
                if length(t_range) < TimestepsPerRepPeriod
                    @info "Skipping subperiod $sp (incomplete)"
                    continue
                end

                # Store only metadata (not the full case)
                subperiod_metadata[sp] = Dict(
                    :sp => sp,
                    :t_range => t_range,
                    :TimestepsPerRepPeriod => TimestepsPerRepPeriod,
                    :SubperiodPolicyConstraints => SubperiodPolicyConstraints,
                    :weight_per_hour => weight_per_hour,
                    :period_index => s
                )
            end

            prep_time = time() - prep_start
            @info "Master preparation complete in $(round(prep_time; digits=2)) seconds"

            # Distribute empty dicts (Benders pattern - no verbose output)
            @info "Distributing subperiod cases to workers"
            subperiods_distributed = distribute([Dict() for _ in 1:num_sub])
            @info "Distribution complete"

            # Variables needed for workers
            out_name = mysetup["ClusterSubperiodFileName"]
            sub_results_dir = v ? (GLOBAL_NUM_PERIODS[] == 1 ?
                joinpath(case_path, "subperiod_results") :
                joinpath(case_path, "subperiod_results_$(s)")) : ""

            # Create subperiod results folder for debug outputs if v=true
            if v
                mkpath(sub_results_dir)
            end

            # Each worker creates and solves its local subperiods, returning DataFrames
            # Use @spawnat to dispatch work, then fetch results
            worker_futures = [@spawnat p begin
                W_local = localindices(subperiods_distributed)[1]
                # Send case_s and metadata to worker (inside @spawnat)
                case_s_worker = case_s
                metadata_local = [subperiod_metadata[k] for k in W_local]

                # Create subperiod cases on worker
                subperiod_data_local = Vector{Dict}(undef, length(W_local))
                for idx in 1:length(W_local)
                    meta = metadata_local[idx]

                    # Create subperiod case on worker
                    case_sub = deepcopy(case_s_worker)

                    # Optionally disable policy constraints
                    if meta[:SubperiodPolicyConstraints] == 0
                        for sys in case_sub.systems
                            disable_policy_constraints!(sys)
                        end
                    end

                    # Restrict time_data for each commodity
                    for sys in case_sub.systems
                        for c in keys(sys.time_data)
                            td = sys.time_data[c]
                            td.time_interval = meta[:t_range]
                            td.subperiods = [meta[:t_range]]
                            td.subperiod_indices = [1]
                            td.subperiod_weights = Dict(1 => meta[:weight_per_hour])
                            td.subperiod_map = Dict(t => 1 for t in meta[:t_range])
                            td.period_index = meta[:period_index]
                        end
                    end

                    subperiod_data_local[idx] = Dict(:sp => meta[:sp], :case_sub => case_sub)
                end

                # Solve local subperiods and return DataFrames
                solve_local_subperiods_df(
                    subperiod_data_local,
                    optimizer, optimizer_env, optimizer_attributes,
                    Zero_Threshold,
                    sub_cfg,
                    out_name,
                    sub_results_dir;
                    v=v
                )
            end for p in pids]

            # Collect results from all workers
            @info "Collecting results from workers"
            all_results = []
            for future in worker_futures
                worker_result = fetch(future)
                append!(all_results, worker_result)
            end

            # Sort by subperiod number to maintain order
            sort!(all_results, by = r -> r.sp)

            # Stack DataFrames in order
            @info "Stacking $(length(all_results)) subperiod results"
            combined_df = DataFrame()
            for result in all_results
                if nrow(result.df) > 0
                    append!(combined_df, result.df)
                end
            end

            # Sort by time index
            if nrow(combined_df) > 0 && :Time_Index in names(combined_df)
                sort!(combined_df, :Time_Index)
            end

            # Write final merged file
            system_path = joinpath(case_path, "system")
            base_name = mysetup["ClusterSubperiodFileName"]
            file = (GLOBAL_NUM_PERIODS[] == 1) ? base_name * ".csv" : base_name * "_" * string(s) * ".csv"
            out_file = joinpath(system_path, file)
            CSV.write(out_file, combined_df)
            @info "Combined stacked file written to: $out_file"
        end

        subperiods_solve_time = time() - subperiods_solve_start
        write_subperiods_solve_time(case_path, subperiods_solve_time; period_idx = s)

        @info "Finished generating subperiod flow matrices period $s"
    end

    GLOBAL_TDR_FLAG[] = 1
    println("=== Subperiod output-based TDR completed for $num_periods subperiods ===")
    println()

    return nothing
end


