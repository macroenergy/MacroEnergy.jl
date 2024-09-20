Base.@kwdef mutable struct TimeData{T} <: AbstractTimeData{T}
    time_interval::StepRange{Int64,Int64}

    hours_per_timestep::Int64 = 1
    subperiods::Vector{StepRange{Int64,Int64}} = StepRange{Int64,Int64}[]
    subperiod_indices::Vector{Int64} = Vector{Int64}()
    subperiod_weights::Dict{Int64,Float64} = Dict{Int64,Float64}()
end


######### TimeData interface #########
current_subperiod(y::Union{AbstractVertex,AbstractEdge}, t::Int64) =
    subperiod_indices(y)[findfirst(t .∈ subperiods(y))];
commodity_type(n::TimeData{T}) where {T} = T;
get_subperiod(y::Union{AbstractVertex,AbstractEdge}, w::Int64) = subperiods(y)[w];
hours_per_timestep(y::Union{AbstractVertex,AbstractEdge}) = y.timedata.hours_per_timestep;
subperiods(y::Union{AbstractVertex,AbstractEdge}) = y.timedata.subperiods;
subperiod_indices(y::Union{AbstractVertex,AbstractEdge}) = y.timedata.subperiod_indices;
subperiod_weight(y::Union{AbstractVertex,AbstractEdge}, w::Int64) =
    y.timedata.subperiod_weights[w];
time_interval(y::Union{AbstractVertex,AbstractEdge}) = y.timedata.time_interval;
######### TimeData interface #########


@doc raw"""
timestepbefore(t::Int, h::Int,subperiods::Vector{StepRange{Int64,Int64})

Determines the time step that is h steps bßefore index t in
subperiod p with circular indexing.

"""
function timestepbefore(t::Int, h::Int, subperiods::Vector{StepRange{Int64,Int64}})::Int
    #Find the subperiod that contains time t
    w = subperiods[findfirst(t .∈ subperiods)]
    #circular shift of the subperiod forward by h steps
    wc = circshift(w, h)

    return wc[findfirst(w .== t)]

end
