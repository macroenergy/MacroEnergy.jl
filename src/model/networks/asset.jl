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

function print_struct_info(asset::AbstractAsset)
    info = struct_info(typeof(asset))
    print_struct_info(info) 
end

function print_struct_info(asset::Type{<:AbstractAsset})
    info = struct_info(asset)
    print_struct_info(info) 
end

function print_struct_info(info::Vector{Tuple{Symbol, Type}})
    for (name, type) in info
        println("Field: $name, Type: $type")
    end    
end

# The following functions are used to extract all the assets of a given type from a System or a Vector of Assets
function get_assets_sametype(assets::Vector{AbstractAsset}, asset_type::T) where T<:Type{<:AbstractAsset}
    return filter(a -> typeof(a) == asset_type, assets)
end

function get_component_by_fieldname(asset::AbstractAsset, fieldname::Symbol)
    return getfield(asset, fieldname)
end

function get_component_ids(asset::AbstractAsset)
    return [id(getfield(asset, t)) for t in fieldnames(typeof(asset))]
end

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
get_edges(asset::AbstractAsset; return_ids_map::Bool=false) = return_ids_map ? get_macro_objs_with_map(asset, AbstractEdge) : get_macro_objs(asset, AbstractEdge)
get_edges(assets::Vector{<:AbstractAsset}; return_ids_map::Bool=false) = return_ids_map ? get_macro_objs_with_map(assets, AbstractEdge) : get_macro_objs(assets, AbstractEdge)

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
