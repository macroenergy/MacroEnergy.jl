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

Determines the time step that is h steps before index t in
subperiod p with circular indexing.

"""
function timestepbefore(t::Int, h::Int, subperiods::Vector{StepRange{Int64,Int64}})::Int
    #Find the subperiod that contains time t
    w = subperiods[findfirst(t .∈ subperiods)]
    #circular shift of the subperiod forward by h steps
    wc = circshift(w, h)

    return wc[findfirst(w .== t)]

end

function write_2_json(time_data::TimeData)
    return Dict(
        :PeriodLength => length(time_data.time_interval),
        :HoursPerTimeStep => step.(time_data.subperiods)[1],
        :HoursPerSubperiod => length.(time_data.subperiods)[1]
    )
end

function write_2_json(time_data::Dict{Symbol, TimeData})
    json_output = Dict{Symbol, Any}(
        :PeriodLength => Dict{Symbol, Int64}(),
        :HoursPerTimeStep => Dict{Symbol, Int64}(),
        :HoursPerSubperiod => Dict{Symbol, Int64}()
    )
    for (k, v) in time_data
        json_data = write_2_json(v)
        json_output[:PeriodLength][k] = json_data[:PeriodLength]
        json_output[:HoursPerTimeStep][k] = json_data[:HoursPerTimeStep]
        json_output[:HoursPerSubperiod][k] = json_data[:HoursPerSubperiod]
    end
    keys_to_collapse = [:PeriodLength]
    # If all entries in PeriodLength are the same, we can write it as a single value
    for key in keys_to_collapse
        if all(x -> x == first(values(json_output[key])), values(json_output[key]))
            single_value = first(values(json_output[key]))
            delete!(json_output, key)
            json_output[:key] = single_value
        end
    end
    return json_output
end