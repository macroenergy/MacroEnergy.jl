Base.@kwdef mutable struct System
    data_dirpath::String
    settings::NamedTuple
    commodities::Dict{Symbol, DataType}
    time_data::Dict{Symbol, TimeData}
    assets::Vector{AbstractAsset}
    locations::Vector{Node}
end

function set_data_dirpath!(system::System, data_dirpath::String)
    system.data_dirpath = data_dirpath
end

function add!(system::System, asset::AbstractAsset)
    push!(system.assets, asset)
end

function add!(system::System, location::Node)
    push!(system.locations, location)
end

function empty_system(data_dirpath::String)
    return System(data_dirpath, NamedTuple(), Dict{Symbol, DataType}(), Dict{Symbol, TimeData}(), [], [])
end
