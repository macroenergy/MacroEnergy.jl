mutable struct System <: AbstractSystem
    data_dirpath::String
    settings::NamedTuple
    commodities::Dict{Symbol,DataType}
    time_data::Dict{Symbol,TimeData}
    assets::Vector{AbstractAsset}
    locations::Vector{Union{Node, Location}}
end

function asset_ids(system::System; source::String="assets")
    if source == "assets"
        if isempty(system.assets)
            @warn("System does not have any assets. Set source to 'inputs' to load assets from the input files.")
            return Set{AssetId}()
        end
        return map(x -> x.id, system.assets)
    elseif source == "inputs"
        return asset_ids_from_dir(system)
    else
        @error("Invalid source $source. Must be 'assets' or 'inputs'")
        return Set{AssetId}()
    end
end
location_ids(system::System) = map(x -> x.id, system.locations)
get_asset_types(system::System) = map(x -> typeof(x), system.assets)

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
    @debug("Creating empty system, with data relative path set to $data_dirpath")
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

function find_locations(system::System, id::Symbol)
    for location in system.locations
        if location.id == id
            return location
        end
    end
    return nothing
end

function find_node(nodes_list::Vector{Union{Node, Location}}, id::Symbol, commodity::Union{Missing,DataType}=missing)
    @debug "Finding node $id of commodity $commodity"
    for node in nodes_list
        # Please reformat the code below
        candidate = find_node(node, id, commodity)
        if candidate !== nothing
            return candidate
        end
    end
    error("Node $id not found")
    return nothing
end

function find_node(node::Node, id::Symbol, commodity::Union{Missing,DataType}=missing)
    if node.id == id
        return node
    end
    return nothing
end

function find_node(location::Location, id::Symbol, commodity::Union{Missing,DataType}=missing)
    # If commodity is missing, skip
    if commodity === missing
        return nothing
    end
    if location.id == id
        commodity_symbol = typesymbol(commodity)
        if commodity_symbol in location.commodities
            @debug "Found $commodity node called $id"
            # If the location has a node of the commodity we need, return it
            return location.nodes[commodity_symbol]
        elseif location.system.settings.AutoCreateNodes
            # Otherwise, create a new node of the commodity and return it
            @debug "Making $commodity node called $id"
            new_node = Node{commodity}(;
                id = id,
                timedata = location.system.time_data[commodity_symbol]
            )
            add_node!(location, new_node)
            push!(location.system.locations, new_node)
            return new_node
        else
            @warn("Node $id not found\nNot creating a new Node as AutoCreateNodes = false")
        end
    end
    return nothing
end

# The following functions are used to extract all the assets of a given type from a System or a Vector of Assets
get_assets_sametype(system::System, asset_type::T) where T<:Type{<:AbstractAsset} = get_assets_sametype(system.assets, asset_type)

# Function to extract all the nodes, edges, storages, and transformations from a system
# If return_ids_map=True, a `Dict` is also returned mapping edge ids to the corresponding asset objects.
get_nodes(system::System) = system.locations
get_edges(system::System; return_ids_map::Bool=false) = return_ids_map ? get_macro_objs_with_map(system, AbstractEdge) : get_macro_objs(system, AbstractEdge)
get_storage(system::System; return_ids_map::Bool=false) = return_ids_map ? get_macro_objs_with_map(system, Storage) : get_macro_objs(system, Storage)
get_transformations(system::System; return_ids_map::Bool=false) = return_ids_map ? get_macro_objs_with_map(system, Transformation) : get_macro_objs(system, Transformation)

# Function to extract the edges with capacity variables from a system.
# If return_ids_map=True, a `Dict` is also returned mapping edge ids to the corresponding asset objects.  
function edges_with_capacity_variables(system::System; return_ids_map::Bool=false)
    if return_ids_map
        edges, edge_asset_map = get_edges(system, return_ids_map=true)
        edges_with_capacity = edges_with_capacity_variables(edges)
        edges_with_capacity_asset_map = filter(edge -> edge[1] in id.(edges_with_capacity), edge_asset_map)
        return edges_with_capacity, edges_with_capacity_asset_map
    else
        return edges_with_capacity_variables(system.assets)
    end
end

function asset_ids_from_file(asset_file::AbstractString, ids::Set{AssetId}=Set{AssetId}())
    if !isfile(asset_file)
        @error("Asset file $asset_file not found")
        return Set{AssetId}()
    end
    asset_data = load_inputs(asset_file)
    for asset_type in values(asset_data)
        ids = asset_ids_from_file(asset_type, ids)
    end
    return ids
end

function asset_ids_from_file(asset_type::Dict{Symbol,Any}, ids::Set{AssetId}=Set{AssetId}())
    if isa(asset_type[:instance_data], Dict{Symbol,Any})
        asset_type[:instance_data] = [asset_type[:instance_data]]
    end
    for asset in asset_type[:instance_data]
        if !haskey(asset, :id)
            @warn("Asset $(asset_type[:type]) does not have an id. Skipping...")
            continue
        end
        asset_id = AssetId(asset[:id])
        if asset_id ∈ ids
            @warn("Duplicate asset id $asset_id. Skipping...")
            continue
        end
        push!(ids, asset_id)
    end
    return ids
end

function asset_ids_from_file(data::AbstractVector, ids::Set{AssetId}=Set{AssetId}())
    for asset_type in data
        ids = asset_ids_from_file(asset_type, ids)
    end
    return ids
end

function asset_ids_from_dir(dirpath::AbstractString, ids::Set{AssetId}=Set{AssetId}())
    for (root, dirs, files) in Base.Filesystem.walkdir(dirpath)
        for file in files
            if endswith(file, ".json") || endswith(file, ".csv")
                ids = asset_ids_from_file(joinpath(root, file), ids)
            end
        end
    end
    return ids
end

function asset_ids_from_dir(system::System, ids::Set{AssetId}=Set{AssetId}())
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    assets_dir = joinpath(system.data_dirpath, system_data[:assets][:path])
    if !isdir(assets_dir)
        @error("Assets directory $assets_dir not found")
        return Set{AssetId}()
    end
    return asset_ids_from_dir(assets_dir, ids)
end

function unique_id(base_id::AssetId, existing_ids::Union{Set{AssetId},AbstractVector{AssetId}})
    id = base_id
    i = 1
    while id ∈ existing_ids
        id = AssetId(string(base_id, "_", i))
        i += 1
    end
    return id
end
