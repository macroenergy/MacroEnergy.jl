function pre_clustering_tdr(case_path::String, mysetup::Dict; period_idx::Int = 1, v::Bool=false)

    TimestepsPerRepPeriod = mysetup["TimestepsPerRepPeriod"]
    ScalingMethod = mysetup["ScalingMethod"]
    NumberOfSubperiods = mysetup["NumberOfSubperiods"]
    UseExtremePeriods = mysetup["UseExtremePeriods"]
    ExtPeriodSelections = mysetup["ExtremePeriods"]
    ClusterAvailability = mysetup["ClusterAvailability"]
    ClusterDemand = mysetup["ClusterDemand"]
    ClusterFuelPrices = mysetup["ClusterFuelPrices"]
    ClusterSubperiodResults = mysetup["ClusterSubperiodResults"]

    ###########################################################
    ################### Step 1 - Load Files ###################
    ###########################################################

    println("=== Step 1: Load Files ===")

    system_path = joinpath(case_path, "system")

    availability = DataFrame()
    demand = DataFrame()
    fuel_prices = DataFrame()
    subperiod_results = DataFrame()

    # File names
    if mysetup["ClusterAvailability"] == 1
        avail_base_name = mysetup["AvailabilityFileName"]
        if GLOBAL_NUM_PERIODS[] == 1
            avail_file_name = avail_base_name * ".csv"
        else
            avail_file_name = avail_base_name * "_" * string(period_idx) * ".csv"
        end
        avail_path = joinpath(system_path, avail_file_name)
        availability = DataFrame(CSV.File(avail_path))
        Nhours_full = (nrow(availability) ÷ TimestepsPerRepPeriod) * TimestepsPerRepPeriod
        availability = availability[1:Nhours_full, :]
        if v println("Loaded availability $(size(availability)) from $avail_path") end
    end

    if mysetup["ClusterDemand"] == 1
        demand_base_name = mysetup["DemandFileName"]
        if GLOBAL_NUM_PERIODS[] == 1
            demand_file_name = demand_base_name * ".csv"
        else
            demand_file_name = demand_base_name * "_" * string(period_idx) * ".csv"
        end
        demand_path = joinpath(system_path, demand_file_name)
        demand = DataFrame(CSV.File(demand_path))
        Nhours_full = (nrow(demand) ÷ TimestepsPerRepPeriod) * TimestepsPerRepPeriod
        demand = demand[1:Nhours_full, :]
        if v println("Loaded demand $(size(demand)) from $demand_path") end
    end

    if mysetup["ClusterFuelPrices"] == 1
        fuel_base_name = mysetup["FuelPricesFileName"]
        if GLOBAL_NUM_PERIODS[] == 1
            fuel_file_name = fuel_base_name * ".csv"
        else
            fuel_file_name = fuel_base_name * "_" * string(period_idx) * ".csv"
        end
        fuel_path = joinpath(system_path, fuel_file_name)
        fuel_prices = DataFrame(CSV.File(fuel_path))
        Nhours_full = (nrow(fuel_prices) ÷ TimestepsPerRepPeriod) * TimestepsPerRepPeriod
        fuel_prices = fuel_prices[1:Nhours_full, :]
        if v println("Loaded fuel prices $(size(fuel_prices)) from $fuel_path") end
    end

    if mysetup["ClusterSubperiodResults"] == 1
        subperiod_base_name = mysetup["ClusterSubperiodFileName"]
        if GLOBAL_NUM_PERIODS[] == 1
            subperiod_file_name = subperiod_base_name * ".csv"
        else
            subperiod_file_name = subperiod_base_name * "_" * string(period_idx) * ".csv"
        end
        subperiod_results_path = joinpath(system_path, subperiod_file_name)
        subperiod_results = DataFrame(CSV.File(subperiod_results_path))
        Nhours_full = (nrow(subperiod_results) ÷ TimestepsPerRepPeriod) * TimestepsPerRepPeriod
        subperiod_results = subperiod_results[1:Nhours_full, :]

        if v println("Loaded subperiod results $(size(subperiod_results)) from $subperiod_results_path") end
    end

    

    println("=== Completed ===") 
    println()

    #########################################################################
    ################### Step 2 - Preparing for clustering ###################
    #########################################################################

    println("=== Step 2: Combine, Remove Const Columns, Normalize Inputs ===")

    # Combine all time series for clustering
    # Drop any Time or Index columns before combining

    drop_time_columns!(availability)
    drop_time_columns!(demand)
    drop_time_columns!(fuel_prices)
    drop_time_columns!(subperiod_results)


    # Combine active DataFrames into one clustering matrix
    dfs_to_combine = []
    if ClusterAvailability == 1 push!(dfs_to_combine, availability) end
    if ClusterDemand == 1 push!(dfs_to_combine, demand) end
    if ClusterFuelPrices == 1 push!(dfs_to_combine, fuel_prices) end
    if ClusterSubperiodResults == 1 push!(dfs_to_combine, subperiod_results) end

    if isempty(dfs_to_combine)
        error("No active time series selected for clustering. Enable at least one of ClusterAvailability, ClusterDemand, ClusterFuelPrices, or ClusterSubperiodResults in TDR_settings.json.")
    end

    full_df = hcat(dfs_to_combine...)

    if v println("Combined time series: ", size(full_df)) end

    # Remove constant columns
    non_constant_cols = [c for c in names(full_df) if std(skipmissing(full_df[!, c])) > 1e-6]
    df_filtered = full_df[:, non_constant_cols]
    if v println("Removed $(size(full_df,2) - size(df_filtered,2)) constant columns") end

    # Normalize or standardize based on ScalingMethod
    ColNames = names(df_filtered)
    InputData = DataFrame(Dict(ColNames[c] => df_filtered[!, ColNames[c]] for c in 1:length(ColNames)))
    Nhours = nrow(InputData)

    if v
        println("Load (MW) and Capacity Factor Profiles: ")
        println(describe(InputData))
        println()
    end

    # Force all columns to Float64 to avoid issues
    for c in ColNames
        InputData[!, c] = Float64.(InputData[!, c])
    end

    # Normalize or standardize directly column by column (keeping names)
    if ScalingMethod == "N"
        normProfiles = [StatsBase.transform(fit(UnitRangeTransform, InputData[!, ColNames[c]]; dims=1, unit=true),InputData[!, ColNames[c]]) for c in 1:length(ColNames)]
    elseif ScalingMethod == "S"
        normProfiles = [
            StatsBase.transform(fit(ZScoreTransform, InputData[!, ColNames[c]]; dims=1, center=true, scale=true),InputData[!, ColNames[c]]) for c in 1:length(ColNames)]
    else
        println("ERROR InvalidScalingMethod: Use N for Normalization or S for Standardization.")
        println("CONTINUING using 0→1 normalization...")
        normProfiles = [StatsBase.transform(fit(UnitRangeTransform, InputData[!, ColNames[c]]; dims=1, unit=true),InputData[!, ColNames[c]]) for c in 1:length(ColNames)]
    end

    # Compile normalized DataFrame
    AnnualTSeriesNormalized = DataFrame(Dict(ColNames[c] => normProfiles[c] for c in 1:length(ColNames)))

    if v 
        println("Load (MW) and Capacity Factor Profiles NORMALIZED! ")
        println(describe(AnnualTSeriesNormalized))
        println()
    end

    println("=== Completed ===") 
    println()

    ###############################################################
    ################### Step 3 - Extreme Periods ##################
    ###############################################################

    println("== Step 3: Identify and Remove Extreme Periods ===")

    if UseExtremePeriods == 1
        println("Initializing Extreme Periods Selection")
    else
        println("Not Using Extreme Periods, Skipping Step")
    end

    NumDataPoints = Nhours ÷ TimestepsPerRepPeriod  # e.g., 364 weeks in 7 years
    if v 
        println("Total Subperiods in the data set: ", NumDataPoints) 
    end
    
    # Assign groups as integers
    InputData[:, :Group] .= (1:Nhours) .÷ (TimestepsPerRepPeriod+0.0001) .+ 1    # Group col identifies the subperiod ID of each hour (e.g., all hours in week 2 have Group=2 if using TimestepsPerRepPeriod=168)
        
    # Identify main column groups
    demand_col_names = [string(c) for c in names(InputData)
        if occursin("load", lowercase(string(c))) || occursin("demand", lowercase(string(c)))]

        solar_col_names = [string(c) for c in names(InputData)
            if (occursin("pv", lowercase(string(c))) || occursin("solar", lowercase(string(c)))) && !occursin("edge", lowercase(string(c)))]
        
        wind_col_names = [string(c) for c in names(InputData)
            if occursin("wind", lowercase(string(c))) && !occursin("edge", lowercase(string(c)))]        

    # Group by period (e.g., week)
    cgdf = combine(groupby(InputData, :Group), [c .=> sum for c in ColNames])
    cgdf = cgdf[setdiff(1:end, NumDataPoints+1), :]
    rename!(cgdf, [:Group; Symbol.(ColNames)]) 

    # Identify extreme periods
    ExtremeWksList = Int[]

    if UseExtremePeriods == 1
        
        for profKey in keys(ExtPeriodSelections)
            for geoKey in keys(ExtPeriodSelections[profKey])
                for typeKey in keys(ExtPeriodSelections[profKey][geoKey])
                    for statKey in keys(ExtPeriodSelections[profKey][geoKey][typeKey])
                        if ExtPeriodSelections[profKey][geoKey][typeKey][statKey] == 1
                            if geoKey == "System"
                                (stat, group_idx) = get_extreme_period(
                                    InputData, cgdf, profKey, typeKey, statKey,
                                    demand_col_names, solar_col_names, wind_col_names; v=v
                                )                   
                                push!(ExtremeWksList, floor(Int, group_idx))
                                if v println(floor(Int, group_idx), " : ", stat) end
                            else
                                println(" -- Error: Geography Key ", geoKey, " is invalid. Select `System'.")
                            end
                        end
                    end
                end
            end
        end
        sort!(unique!(ExtremeWksList))
        println(" Extreme Periods ", ExtremeWksList)
    end

    println("=== Completed ===") 
    println()

    #######################################################################
    ################### Step 4 - Reshape Normalized Data ##################
    #######################################################################
    
    println("== Step 4: Reshape Normalized Data for Clustering ===")

    ### DATA MODIFICATION - Shifting InputData and Normalized InputData
    #    from 8760 (# hours) by n (# profiles) DF to
    #    168*n (n period-stacked profiles) by 52 (# periods) DF
    AnnualTSeriesNormalized[:, :Group] .= (1:Nhours) .÷ (TimestepsPerRepPeriod+0.0001) .+ 1
    DFsToConcatNorm = [stack(AnnualTSeriesNormalized[isequal.(AnnualTSeriesNormalized.Group,w),:], ColNames)[!,:value] for w in 1:NumDataPoints if w <= NumDataPoints ]
    ModifiedDataNormalized = DataFrame(Dict(Symbol(i) => DFsToConcatNorm[i] for i in 1:NumDataPoints))

    if v
        println("Features: ", length(ColNames))
        println("Timesteps per feature: ", TimestepsPerRepPeriod)
        println("ModifiedDataNormalized shape: ", size(ModifiedDataNormalized))
    end

    # Remove extreme periods from clustering input
    NClusters = NumberOfSubperiods
    if UseExtremePeriods == 1 && !isempty(ExtremeWksList)
        # Remove extreme period columns by name
        ClusteringInputDF = select(ModifiedDataNormalized, Not(string.(ExtremeWksList)))
        # Adjust cluster count
        NClusters -= length(ExtremeWksList)
        if v
            println("Pre-removal columns: ", names(ModifiedDataNormalized))
            println("Extreme periods to remove: ", string.(ExtremeWksList))
            println("Post-removal columns: ", names(ClusteringInputDF))
        end
    else
        ClusteringInputDF = ModifiedDataNormalized
    end

    println("Shape of ModifiedDataNormalized: ", size(ModifiedDataNormalized))
    println("Shape of ClusteringInputDF: ", size(ClusteringInputDF))
    println("NClusters after extreme removal: ", NClusters)
    println("=== Completed ===")
    println()

    return (ClusteringInputDF, ModifiedDataNormalized, NClusters, ExtremeWksList)
end
