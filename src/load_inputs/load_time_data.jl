function load_time_data(
    data::AbstractDict{Symbol,Any},
    commodities::Dict{Symbol,DataType},
    rel_path::AbstractString
)
    if haskey(data, :path)
        path = rel_or_abs_path(data[:path], rel_path)
        return load_time_data(path, commodities, rel_path)
    else
        return load_time_data(data, commodities)
    end
end

function load_time_data(
    path::AbstractString,
    commodities::Dict{Symbol,DataType},
    rel_path::AbstractString
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
    haskey(time_data, :PeriodMap) && load_period_map!(time_data, rel_path)
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

function load_period_map!(
    time_data::AbstractDict{Symbol,Any},
    rel_path::AbstractString
)
    period_map_data = time_data[:PeriodMap]
    # if the period map is file path, load it
    if haskey(period_map_data, :path)
        path = rel_or_abs_path(period_map_data[:path], rel_path)
        period_map_data = load_period_map(path)
    end
    validate_period_map(period_map_data)
    time_data[:PeriodMap] = period_map_data
end

function load_period_map(path::AbstractString)
    isfile(path) || error("Period map file not found at $(abspath(path))")
    return load_csv(path)
end

function validate_period_map(period_map_data::DataFrame)
    @assert names(period_map_data) == ["Period_Index", "Rep_Period", "Rep_Period_Index"]
    @assert typeof(period_map_data[!, :Period_Index]) == Vector{Union{Missing, Int}}
    @assert typeof(period_map_data[!, :Rep_Period]) == Vector{Union{Missing, Int}}
    @assert typeof(period_map_data[!, :Rep_Period_Index]) == Vector{Union{Missing, Int}}
end

function validate_time_data(
    time_data::AbstractDict{Symbol,Any},
    case_commodities::Dict{Symbol,DataType}
)
    # Check that the time data has the correct fields
    @assert haskey(time_data, :PeriodLength)
    @assert haskey(time_data, :HoursPerTimeStep)
    @assert haskey(time_data, :HoursPerSubperiod)
    # Check that the time data has the correct values    
    @assert time_data[:PeriodLength] > 0
    @assert all(values(time_data[:HoursPerTimeStep]) .> 0)
    @assert all(values(time_data[:HoursPerSubperiod]) .> 0)

    # validate period map
    haskey(time_data, :PeriodMap) && validate_period_map(time_data[:PeriodMap])

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
    period_length = time_data[:PeriodLength]

    time_interval = 1:period_length
    
    hours_per_timestep = time_data[:HoursPerTimeStep][sym]

    validate_temporal_resolution(hours_per_timestep)

    subperiods = create_subperiods(time_data, sym)

    period_map  = get_timedata_period_map(time_data, sym)

    unique_rep_periods = get_unique_rep_periods(period_map)

    weights = get_weights(period_map, unique_rep_periods)

    return TimeData{type}(;
        time_interval = time_interval,
        hours_per_timestep = hours_per_timestep,
        subperiods = subperiods,
        subperiod_indices = unique_rep_periods,
        subperiod_weights = Dict(unique_rep_periods .=> weights),
        period_map = period_map
    )
end

function validate_temporal_resolution(hours_per_timestep::Int)
    hours_per_timestep != 1 && error("Macro does not support different temporal resolutions yet. Please use hourly resolution for all comoodities.")
end

function create_subperiods(time_data::AbstractDict{Symbol,Any}, sym::Symbol)
    period_length = time_data[:PeriodLength]
    time_interval = 1:period_length
    hours_per_subperiod = time_data[:HoursPerSubperiod][sym]
    return collect(Iterators.partition(time_interval, hours_per_subperiod))
end


function get_unique_rep_periods(period_map::Dict{Int64, Int64})
    
    rep_periods = collect(values(period_map))

    return sort(unique(rep_periods))

end

function get_weights(period_map::Dict{Int64, Int64}, unique_rep_periods::Vector{Int64})

    rep_periods = collect(values(period_map))    # list of rep periods for each subperiod

    return Int[length(findall(rep_periods .== p)) for p in unique_rep_periods]
end

function get_timedata_period_map(time_data::AbstractDict{Symbol,Any}, sym::Symbol)
    if haskey(time_data, :PeriodMap)
        return Dict(time_data[:PeriodMap][!, :Period_Index] .=> time_data[:PeriodMap][!, :Rep_Period])
    # if no period map, return a dictionary with the subperiods as keys and values
    # Note: this is the default behavior for the period map
    else
        subperiods = create_subperiods(time_data, sym)
        return Dict(eachindex(subperiods) .=> eachindex(subperiods))
    end
end
