mutable struct System
    data_dirpath::String
    settings::NamedTuple
    commodities::Dict{Symbol,DataType}
    time_data::Dict{Symbol,TimeData}
    assets::Vector{AbstractAsset}
    locations::Vector{Node}
end

asset_ids(system::System) = map(x -> x.id, system.assets)
location_ids(system::System) = map(x -> x.id, system.locations)

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
    return System(
        data_dirpath,
        NamedTuple(),
        Dict{Symbol,DataType}(),
        Dict{Symbol,TimeData}(),
        [],
        [],
    )
end

function get_asset_by_id(system::System, id::Symbol)
    for asset in system.assets
        if asset.id == id
            return asset
        end
    end
    return nothing
end

function find_node(nodes_list::Vector{Node}, id::Symbol)
    for node in nodes_list
        if node.id == id
            return node
        end
    end
    error("Vertex $id not found")
    return nothing
end