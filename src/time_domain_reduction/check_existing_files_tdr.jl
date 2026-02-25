function tdr_inputs_exist(tdr_output_path::String, mysetup::Dict; period_idx::Int = 1)::Bool

    filenames = String[]

    if mysetup["ClusterAvailability"] == 1
        avail_base_name = mysetup["AvailabilityFileName"]
        if GLOBAL_NUM_PERIODS[] == 1
            avail_file_name = avail_base_name * ".csv"
        else
            avail_file_name = avail_base_name * "_" * string(period_idx) * ".csv"
        end
        push!(filenames, avail_file_name)
    end

    if mysetup["ClusterDemand"] == 1
        demand_base_name = mysetup["DemandFileName"]
        if GLOBAL_NUM_PERIODS[] == 1
            demand_file_name = demand_base_name * ".csv"
        else
            demand_file_name = demand_base_name * "_" * string(period_idx) * ".csv"
        end
        push!(filenames, demand_file_name)
    end

    if mysetup["ClusterFuelPrices"] == 1
        fuel_base_name = mysetup["FuelPricesFileName"]
        if GLOBAL_NUM_PERIODS[] == 1
            fuel_file_name = fuel_base_name * ".csv"
        else
            fuel_file_name = fuel_base_name * "_" * string(period_idx) * ".csv"
        end
        push!(filenames, fuel_file_name)
    end

    # If no inputs are required, nothing exists
    isempty(filenames) && return false

    # Check existence
    for fname in filenames
        fpath = joinpath(tdr_output_path, fname)
        if !isfile(fpath)
            return false   # not all exist
        end
    end

    return true  # all exist
end
