function load_time_data(
    data::AbstractDict{Symbol,Any},
    commodities::Dict{Symbol,DataType},
    rel_path::AbstractString
)
    period_index = get(data, :SystemIndex, 1)
    if haskey(data, :path)
        path = rel_or_abs_path(data[:path], rel_path)
        return load_time_data(path, commodities, rel_path, period_index)
    else
        return load_time_data(data, commodities)
    end
end

function load_time_data(
    path::AbstractString,
    commodities::Dict{Symbol,DataType},
    rel_path::AbstractString,
    period_index::Int = 1
)
    path = rel_or_abs_path(path, rel_path)
    if isdir(path)
        path = joinpath(path, "time_data.json")
    end
    # read in the list of commodities from the data directory
    isfile(path) || error("Time data not found at $(abspath(path))")

    # Before reading the time data into the macro data structures
    # we make sure that the period map is loaded
    time_data = copy(JSON3.read(path))
    haskey(time_data, :SubPeriodMap) && load_subperiod_map!(time_data, rel_path)
    validate_and_set_default_total_hours_modeled!(time_data::AbstractDict{Symbol,Any})
    time_data[:SystemIndex] = period_index
    return load_time_data(time_data, commodities)
end

function load_time_data(
    time_data::AbstractDict{Symbol,Any},
    commodities::Dict{Symbol,DataType}
)
    # validate the time data
    validate_time_data(time_data, commodities)

    # create the time data object
    return create_time_data(time_data, commodities)
end

function load_subperiod_map!(
    time_data::AbstractDict{Symbol,Any},
    rel_path::AbstractString
)
    subperiod_map_data = time_data[:SubPeriodMap]
    # if the period map is file path, load it
    if haskey(subperiod_map_data, :path)
        path = rel_or_abs_path(subperiod_map_data[:path], rel_path)
        subperiod_map_data = load_subperiod_map(path)
    end
    validate_subperiod_map(subperiod_map_data)
    time_data[:SubPeriodMap] = subperiod_map_data
end

function load_subperiod_map(path::AbstractString)
    isfile(path) || error("Period map file not found at $(abspath(path))")
    return load_csv(path)
end

function validate_subperiod_map(subperiod_map_data::DataFrame)
    @assert names(subperiod_map_data) == ["Period_Index", "Rep_Period", "Rep_Period_Index"]
    @assert eltype(subperiod_map_data[!, :Period_Index]) <: Union{Missing, Integer}
    @assert eltype(subperiod_map_data[!, :Rep_Period]) <: Union{Missing, Integer}
    @assert eltype(subperiod_map_data[!, :Rep_Period_Index]) <: Union{Missing, Integer}
end

function validate_and_set_default_total_hours_modeled!(time_data::AbstractDict{Symbol,Any})
    # Check if TotalHoursModeled exists and is an integer
    if haskey(time_data, :TotalHoursModeled)
        if !isa(time_data[:TotalHoursModeled], Integer)
            throw(ArgumentError("TotalHoursModeled must be an integer, got $(typeof(time_data[:TotalHoursModeled]))"))
        end
    # If TotalHoursModeled does not exist, use default value of 8760 (hours per year)
    else
        @warn("TotalHoursModeled not found in time_data.json - Using 8760 as default value for TotalHoursModeled")
        time_data[:TotalHoursModeled] = 8760
    end
end

function validate_time_data(
    time_data::AbstractDict{Symbol,Any},
    case_commodities::Dict{Symbol,DataType}
)
    # Check that the time data has the correct fields
    @assert haskey(time_data, :NumberOfSubperiods)
    @assert haskey(time_data, :HoursPerTimeStep)
    @assert haskey(time_data, :HoursPerSubperiod)
    # Check that the time data has the correct values    
    @assert time_data[:NumberOfSubperiods] > 0
    @assert all(values(time_data[:HoursPerTimeStep]) .> 0)
    @assert all(values(time_data[:HoursPerSubperiod]) .> 0)

    # validate period map
    haskey(time_data, :SubPeriodMap) && validate_subperiod_map(time_data[:SubPeriodMap])

    # Check that the time data has the correct commodities
    @assert keys(time_data[:HoursPerTimeStep]) == keys(time_data[:HoursPerSubperiod])
    @assert keys(time_data[:HoursPerTimeStep]) <= keys(case_commodities)
    macro_commodities = commodity_types(MacroEnergy) # Get the available commodities
    validate_commodities(keys(time_data[:HoursPerTimeStep]), macro_commodities)
    validate_commodities(keys(time_data[:HoursPerSubperiod]), macro_commodities)
end

function create_time_data(
    time_data::AbstractDict{Symbol,Any},
    commodities::Dict{Symbol,DataType}
)
    all_timedata = Dict{Symbol,TimeData}()
    time_data_keys = keys(time_data[:HoursPerTimeStep])
    for (sym, type) in commodities
        if sym in time_data_keys
            all_timedata[sym] = create_commodity_timedata(sym, type, time_data)
        else
            # Check if sym is any of supertypes(type), and if so load the time data from there
            for supertype in supertypes(type)
                if Symbol(supertype) in time_data_keys
                    @debug "Using time data from $(supertype) for $(sym)"
                    all_timedata[sym] = create_commodity_timedata(Symbol(supertype), type, time_data)
                    break
                end
            end
        end
    end
    return all_timedata
end

function create_commodity_timedata(
    sym::Symbol,
    type::DataType,
    time_data::AbstractDict{Symbol,Any}
)
    number_of_subperiods = time_data[:NumberOfSubperiods];

    hours_per_subperiod = time_data[:HoursPerSubperiod][sym]

    total_hours_modeled = time_data[:TotalHoursModeled]

    hours_per_timestep = time_data[:HoursPerTimeStep][sym]

    period_length = number_of_subperiods * hours_per_subperiod;

    time_interval = 1:period_length

    validate_temporal_resolution(hours_per_timestep)

    subperiods = create_subperiods(time_data, sym)

    subperiod_map  = get_timedata_subperiod_map(time_data, sym)

    unique_rep_periods = get_unique_rep_periods(subperiod_map)

    weights = get_weights(subperiod_map, unique_rep_periods, hours_per_subperiod, total_hours_modeled)

    return TimeData{type}(;
        time_interval = time_interval,
        hours_per_timestep = hours_per_timestep,
        period_index = get(time_data, :SystemIndex, 1),
        subperiods = subperiods,
        subperiod_indices = unique_rep_periods,
        subperiod_weights = Dict(unique_rep_periods .=> weights),
        subperiod_map = subperiod_map
    )
end

function validate_temporal_resolution(hours_per_timestep::Int)
    hours_per_timestep != 1 && error("Macro does not support different temporal resolutions yet. Please use hourly resolution for all comoodities.")
end

function create_subperiods(time_data::AbstractDict{Symbol,Any}, sym::Symbol)
    number_of_subperiods = time_data[:NumberOfSubperiods]
    hours_per_subperiod = time_data[:HoursPerSubperiod][sym]
    time_interval = 1:number_of_subperiods * hours_per_subperiod;
    return collect(Iterators.partition(time_interval, hours_per_subperiod))
end


function get_unique_rep_periods(subperiod_map::Dict{Int64, Int64})
    
    rep_periods = collect(values(subperiod_map))

    return sort(unique(rep_periods))

end

function get_weights(subperiod_map::Dict{Int64, Int64}, unique_rep_periods::Vector{Int64}, hours_per_subperiod::Int64, total_hours_modeled::Int64)

    # If no period map provided in time_data.json input, each period maps to itself from get_timedata_subperiod_map
    is_identity_mapping = all(subperiod_map[k] == k for k in keys(subperiod_map))

    if is_identity_mapping
        @warn "Using default weights = 1 as no period map provided and each period maps to itself"
        unscaled_weights = [1.0 for _ in unique_rep_periods]
    else

        rep_periods = collect(values(subperiod_map))    # list of rep periods for each subperiod

        unscaled_weights = Int[length(findall(rep_periods .== p)) for p in unique_rep_periods]
    end

    weight_scaling_factor = total_hours_modeled / (sum(unscaled_weights) * hours_per_subperiod)

    scaled_weights = unscaled_weights * weight_scaling_factor

    return scaled_weights
end

function get_timedata_subperiod_map(time_data::AbstractDict{Symbol,Any}, sym::Symbol)
    if haskey(time_data, :SubPeriodMap)
        return Dict(time_data[:SubPeriodMap][!, :Period_Index] .=> time_data[:SubPeriodMap][!, :Rep_Period])
    # if no period map, return a dictionary with the subperiods as keys and values
    # Note: this is the default behavior for the period map
    else
        subperiods = create_subperiods(time_data, sym)
        return Dict(eachindex(subperiods) .=> eachindex(subperiods))
    end
end
