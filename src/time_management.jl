Base.@kwdef mutable struct TimeData{T} <: AbstractTimeData{T}
    timesteps::StepRange{Int64,Int64}
    subperiods::Vector{StepRange{Int64,Int64}} = StepRange{Int64,Int64}[]
    subperiod_weights::Dict{StepRange{Int64,Int64},Float64} = Dict{StepRange{Int64,Int64},Float64}()
    hours::Vector{StepRange{Int64,Int64}} 
end

function create_time_data(settings::NamedTuple)

    all_timedata = Dict();
    for c in keys(settings.Commodities)
        timesteps = 1 : Int.(settings.PeriodLength/settings.Commodities[c][:HoursPerTimeStep]);
        subperiods = collect(Iterators.partition(timesteps, Int(settings.Commodities[c][:HoursPerSubperiod] / settings.Commodities[c][:HoursPerTimeStep])))
        all_timedata[c] = Macro.TimeData{c}(;
        timesteps =  timesteps,
        subperiods = subperiods,
        subperiod_weights = Dict(subperiods.=> settings.Commodities[c][:WeightsPerSubperiod]/settings.Commodities[c][:HoursPerSubperiod]),
        hours =  [((t-1)*settings.Commodities[c][:HoursPerTimeStep] +1 : t*settings.Commodities[c][:HoursPerTimeStep]) for t in timesteps]
        )
    end
    return all_timedata
end



@doc raw"""
    timestepbefore(t::Int, h::Int,subperiods::Vector{StepRange{Int64,Int64})

Determines the time step that is h steps bßefore index t in
subperiod p with circular indexing.

"""
function timestepbefore(t::Int, h::Int,subperiods::Vector{StepRange{Int64,Int64}})::Int
    #Find the subperiod that contains time t
    w = subperiods[findfirst(t .∈ subperiods)]; 
    #circular shift of the subperiod forward by h steps
    wc = circshift(w,h); 

    return wc[findfirst(w.==t)]

end


