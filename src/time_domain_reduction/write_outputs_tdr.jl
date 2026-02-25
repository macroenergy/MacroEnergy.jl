function write_outputs_tdr(case_path::String, myTDRsetup::Dict, PeriodMap::DataFrame, M::Vector{Int}; period_idx::Int = 1, v::Bool=false)
    
    println("=== Write TDR Outputs ===")

    system_path = joinpath(case_path, "system")
    tdr_output_path = joinpath(system_path, myTDRsetup["TimeDomainReductionFolder"])

    if GLOBAL_NUM_PERIODS[] == 1
        period_map_name = "Period_map.csv"
    else
        period_map_name = "Period_map" * "_" * string(period_idx) * ".csv"
    end    

    # Write Period Map
    period_map_path = joinpath(tdr_output_path, period_map_name)

    CSV.write(period_map_path, PeriodMap)
    println("$period_map_name written to $period_map_path")

    # Generate Reduced Input CSVs
    TimestepsPerRepPeriod = myTDRsetup["TimestepsPerRepPeriod"]
    file_keys = ["AvailabilityFileName", "DemandFileName", "FuelPricesFileName"]

    for key in file_keys

        if GLOBAL_NUM_PERIODS[] == 1
            full_path = joinpath(system_path, myTDRsetup[key] * ".csv")
            reduced_path = joinpath(tdr_output_path, myTDRsetup[key] * ".csv")
        else
            full_path = joinpath(system_path, myTDRsetup[key] * "_" * string(period_idx) * ".csv")
            reduced_path = joinpath(tdr_output_path, myTDRsetup[key] * "_" * string(period_idx) * ".csv")
        end

        if isfile(full_path)
            create_reduced_csv(full_path, reduced_path, M, TimestepsPerRepPeriod; v=v)
        else
            println("Missing file: ", full_path, " — skipping reduction.")
        end
    end

    # --- Write time_data.json ---
    write_time_data_json(
        system_path,
        tdr_output_path,
        period_map_name,
        myTDRsetup["TimestepsPerRepPeriod"],
        myTDRsetup["NumberOfSubperiods"],
        myTDRsetup["TotalHoursModeled"];
        period_idx=period_idx,
        v=v
    )

    println("=== Completed ===")
    println()
end