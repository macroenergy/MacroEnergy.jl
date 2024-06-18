Base.@kwdef mutable struct TimeData{T} <: AbstractTimeData{T}
    time_interval::StepRange{Int64,Int64}
    subperiods::Vector{StepRange{Int64,Int64}} = StepRange{Int64,Int64}[]
    subperiod_weights::Dict{StepRange{Int64,Int64},Float64} = Dict{StepRange{Int64,Int64},Float64}()
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


