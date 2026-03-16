"""
    id(asset::AbstractAsset)

Get the unique identifier (ID) of an asset.

# Arguments
- `asset`: An asset object that is a subtype of AbstractAsset

# Returns
- A Symbol representing the asset's unique identifier

# Examples
```julia
thermal_plant = get_asset_by_id(system, :SE_natural_gas)
asset_id = id(thermal_plant)  # Returns the ID of the thermal plant
```
"""
id(asset::AbstractAsset) = asset.id

"""
    struct_info(t::Type{T}) where T

    Return a vector of tuples with the field names and types of a struct.
"""
function struct_info(::Type{T}, include_id::Bool=false) where T
    field_names = Base.fieldnames(T)
    field_types = T.types
    if include_id
        return [(field_names[idx], field_types[idx]) for idx in eachindex(field_names)]
    else
        return [(field_names[idx], field_types[idx]) for idx in eachindex(field_names) if field_names[idx] != :id]
    end
end

function struct_info(asset::T) where T
    return struct_info(typeof(asset))
end

"""
    print_struct_info(asset::AbstractAsset)

Print fields and types of a given asset.

# Arguments
- `asset`: An asset object that is a subtype of AbstractAsset

# Examples
```julia
thermal_plant = get_asset_by_id(system, :SE_natural_gas_fired_combined_cycle_1)
print_struct_info(thermal_plant)  # Prints the fields and types of the asset
```
"""
function print_struct_info(asset::AbstractAsset)
    info = struct_info(typeof(asset))
    print_struct_info(info) 
end

function print_struct_info(asset::Type{<:AbstractAsset})
    info = struct_info(asset)
    print_struct_info(info) 
end

function print_struct_info(info::Vector{Tuple{Symbol, T}}) where T <: Union{Type, UnionAll}
    for (name, type) in info
        println("Field: $name, Type: $type")
    end    
end

# The following functions are used to extract all the assets of a given type from a System or a Vector of Assets
function get_assets_sametype(assets::Vector{AbstractAsset}, asset_type::T) where T<:Type{<:AbstractAsset}
    return filter(a -> typeof(a) == asset_type, assets)
end

"""
    get_component_by_fieldname(asset::AbstractAsset, fieldname::Symbol)

Get a component of an asset by its field name (i.e., fieldname of the asset `struct`).

# Arguments
- `asset`: An asset object that is a subtype of AbstractAsset
- `fieldname`: Symbol representing the field name of the component to get (i.e., fieldname of the asset `struct`)

# Returns
- The component object stored in the specified field

# Examples
```julia
elec_edge = get_component_by_fieldname(thermal_plant, :elec_edge)
```
"""
function get_component_by_fieldname(asset::AbstractAsset, fieldname::Symbol)
    return getfield(asset, fieldname)
end

"""
    get_component_ids(asset::AbstractAsset)

Get the IDs of all components in an asset.

# Arguments
- `asset`: An asset object that is a subtype of AbstractAsset

# Returns
- A vector of Symbols representing the IDs of all components in the asset

# Examples
```julia
component_ids = get_component_ids(thermal_plant)
```
"""
function get_component_ids(asset::AbstractAsset)
    return [id(getfield(asset, t)) for t in fieldnames(typeof(asset))]
end

"""
    get_component_by_id(asset::AbstractAsset, component_id::Symbol)

Find a component (e.g., edges, storages, transformations) of an asset by its ID.

# Arguments
- `asset`: An asset object that is a subtype of AbstractAsset
- `component_id`: Symbol representing the ID of the component to find

# Returns
- The component object if found
- `nothing` if no component with the given ID exists

# Examples
```julia
elec_edge = get_component_by_id(thermal_plant, :SE_natural_gas_elec_edge)
```
"""
function get_component_by_id(asset::AbstractAsset, component_id::Symbol)
    for t in fieldnames(typeof(asset))
        component = getfield(asset, t)
        if isequal(id(component), component_id)
            return component
        end
    end
    return nothing
end

# The following functions are used to extract all the edges from an Asset or a Vector of Assets
# If return_ids_map=True, a `Dict` is also returned mapping edge ids to the corresponding asset objects.
"""
    get_edges(asset::AbstractAsset; return_ids_map::Bool=false)
    get_edges(assets::Vector{<:AbstractAsset}; return_ids_map::Bool=false)

Get all edges from an asset or a vector of assets. If `return_ids_map=true`, a `Dict` is also returned mapping edge ids to the corresponding asset objects.

# Arguments
- `asset` or `assets`: An asset object or vector of assets that are subtypes of AbstractAsset
- `return_ids_map`: If true, also return a Dict mapping edge IDs to their corresponding assets (default: false)

# Returns
- If `return_ids_map=false`: A vector of edges
- If `return_ids_map=true`: A tuple of (vector of edges, Dict mapping edge IDs to assets)

# Examples
```julia
# Get all edges from a single asset
edges = get_edges(thermal_plant)
```
"""
get_edges(asset::AbstractAsset; return_ids_map::Bool=false) = return_ids_map ? get_macro_objs_with_map(asset, AbstractEdge) : get_macro_objs(asset, AbstractEdge)
get_edges(assets::Vector{<:AbstractAsset}; return_ids_map::Bool=false) = return_ids_map ? get_macro_objs_with_map(assets, AbstractEdge) : get_macro_objs(assets, AbstractEdge)

get_storages(asset::AbstractAsset; return_ids_map::Bool=false) = return_ids_map ? get_macro_objs_with_map(asset, AbstractStorage) : get_macro_objs(asset, AbstractStorage)

# The following functions are used to extract the edges with capacity variables from a Vector of Assets or a single Asset.
# If return_ids_map=True, a `Dict` is also returned mapping edge ids to the corresponding asset objects.  
function edges_with_capacity_variables(assets::Vector{<:AbstractAsset}; return_ids_map::Bool=false)
    if return_ids_map
        all_edges = Vector{Vector{AbstractEdge}}(undef, length(assets))
        all_edge_asset_map = Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
        for i in eachindex(assets)
            asset = assets[i]
            edges, edge_asset_map = edges_with_capacity_variables(asset, return_ids_map=true)
            all_edges[i] = edges
            merge!(all_edge_asset_map, edge_asset_map)
        end
        return reduce(vcat, all_edges), all_edge_asset_map
    else
        return reduce(vcat, [edges_with_capacity_variables(asset) for asset in assets])
    end
end
function edges_with_capacity_variables(asset::AbstractAsset; return_ids_map::Bool=false)
    if return_ids_map
        edges, edge_asset_map = get_edges(asset, return_ids_map=true)
        edges_with_capacity = edges_with_capacity_variables(edges)
        edges_with_capacity_asset_map = filter(edge -> edge[1] in id.(edges_with_capacity), edge_asset_map)
        return edges_with_capacity, edges_with_capacity_asset_map
    else
        return AbstractEdge[edge for edge in get_edges(asset) if has_capacity(edge)]
    end
end

function storages_with_capacity_variables(assets::Vector{<:AbstractAsset}; return_ids_map::Bool=false)
    if return_ids_map
        all_storages = Vector{Vector{AbstractStorage}}(undef, length(assets))
        all_storage_asset_map = Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
        for i in eachindex(assets)
            asset = assets[i]
            storages, storage_asset_map = storages_with_capacity_variables(asset, return_ids_map=true)
            all_storages[i] = storages
            merge!(all_storage_asset_map, storage_asset_map)
        end
        return reduce(vcat, all_storages), all_storage_asset_map
    else
        return reduce(vcat, [storages_with_capacity_variables(asset) for asset in assets])
    end
end
function storages_with_capacity_variables(asset::AbstractAsset; return_ids_map::Bool=false)
    if return_ids_map
        storages, storage_asset_map = get_storages(asset, return_ids_map=true)
        #### Note that all storages have capacity variables
        storages_with_capacity = storages
        #### storages_with_capacity = storages_with_capacity_variables(storages)
        storages_with_capacity_asset_map = filter(storage -> storage[1] in id.(storages_with_capacity), storage_asset_map)
        return storages_with_capacity, storages_with_capacity_asset_map
    else
        return AbstractStorage[storage for storage in get_storages(asset)]
    end
end