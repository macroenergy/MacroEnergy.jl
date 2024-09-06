function load_time_data(path::AbstractString, commodities::Dict{Symbol,DataType}, rel_path::AbstractString)
    path = rel_or_abs_path(path, rel_path)
    if isdir(path)
        path = joinpath(path, "time_data.json")
    end
    # read in the list of commodities from the data directory
    isfile(path) || error("Time data not found at $(abspath(path))")
    return load_time_data(JSON3.read(path), commodities)
end

function load_time_data(data::AbstractDict{Symbol, Any}, commodities::Dict{Symbol,DataType}, rel_path::AbstractString)
    if haskey(data, :path)
        path = rel_or_abs_path(data[:path], rel_path)
        return load_time_data(path, commodities, rel_path)
    else
        return load_time_data(data, commodities)
    end
end

function load_time_data(data::AbstractDict{Symbol, Any}, commodities::Dict{Symbol,DataType})
    # validate the time data
    validate_time_data(data, commodities)

    # create the time data object
    return create_time_data(data, commodities)
end

function validate_time_data(time_data::AbstractDict{Symbol, Any}, case_commodities::Dict{Symbol,DataType})
    # Check that the time data has the correct fields
    @assert haskey(time_data, :PeriodLength)
    @assert haskey(time_data, :HoursPerTimeStep)
    @assert haskey(time_data, :HoursPerSubperiod)
    # @assert haskey(time_data, :SubperiodWeights)  # TODO: Implement this

    # Check that the time data has the correct values    
    @assert time_data[:PeriodLength] > 0
    @assert all(values(time_data[:HoursPerTimeStep]) .> 0)
    @assert all(values(time_data[:HoursPerSubperiod]) .> 0)
    
    # Check that the time data has the correct commodities
    @assert keys(time_data[:HoursPerTimeStep]) == keys(time_data[:HoursPerSubperiod])
    @assert keys(time_data[:HoursPerTimeStep]) == keys(case_commodities)
    macro_commodities = commodity_types(Macro) # Get the available commodities
    validate_commodities(keys(time_data[:HoursPerTimeStep]), macro_commodities)
    validate_commodities(keys(time_data[:HoursPerSubperiod]), macro_commodities)
end
 
function create_time_data(time_data::AbstractDict{Symbol,Any}, commodities::Dict{Symbol,DataType})
    period_length = time_data[:PeriodLength]
    all_timedata = Dict{Symbol,TimeData}()
    for (sym,type) in commodities
        hours_per_timestep = time_data[:HoursPerTimeStep][sym]
        time_interval = 1:hours_per_timestep:period_length

        hours_per_subperiod = time_data[:HoursPerSubperiod][sym]
        subperiods = collect(Iterators.partition(time_interval, Int(hours_per_subperiod / hours_per_timestep)))
        weights_per_subperiod = hours_per_subperiod # TODO: Implement this

        all_timedata[sym] = Macro.TimeData{type}(;
            time_interval=time_interval,
            subperiods=subperiods,
            subperiod_weights=Dict(eachindex(subperiods) .=> weights_per_subperiod / hours_per_subperiod),
            subperiod_indices = eachindex(subperiods),
            hours_per_timestep =  time_data[:HoursPerTimeStep][sym]
        )
    end
    return all_timedata
end