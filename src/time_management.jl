Base.@kwdef mutable struct TimeData{T} <: AbstractTimeData{T}
    time_interval::StepRange{Int64,Int64}
    subperiods::Vector{StepRange{Int64,Int64}} = StepRange{Int64,Int64}[]
    subperiod_weights::Dict{StepRange{Int64,Int64},Float64} = Dict{StepRange{Int64,Int64},Float64}()
    hours_per_timestep::Int64 = 1;
end



time_interval(y::Union{AbstractNode,AbstractEdge,AbstractTransform,AbstractTransformationEdge}) = y.timedata.time_interval;
subperiods(y::Union{AbstractNode,AbstractEdge,AbstractTransform,AbstractTransformationEdge}) = y.timedata.subperiods;
subperiod_weight(y::Union{AbstractNode,AbstractEdge,AbstractTransform,AbstractTransformationEdge},w::StepRange{Int64, Int64}) = y.timedata.subperiod_weights[w];
current_subperiod(y::Union{AbstractNode,AbstractEdge,AbstractTransform,AbstractTransformationEdge},t::Int64) = subperiods(y)[findfirst(t .∈ subperiods(y))];
hours_per_timestep(y::Union{AbstractNode,AbstractEdge,AbstractTransform,AbstractTransformationEdge}) = y.timedata.hours_per_timestep;
# hours(y::Union{AbstractNode,AbstractEdge,AbstractTransform,AbstractTransformationEdge},t::Int64) = y.timedata.hours[t];


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


