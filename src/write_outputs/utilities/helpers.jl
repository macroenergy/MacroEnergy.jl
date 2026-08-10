"""
Common helper functions for output generation.
"""

# Get the commodity type of a MacroObject
get_commodity_name(obj::AbstractEdge) = typesymbol(commodity_type(obj))
get_commodity_name(obj::Node) = typesymbol(commodity_type(obj))
get_commodity_name(obj::AbstractStorage) = typesymbol(commodity_type(obj))

# Get the zone name/location of a vertex
get_zone_name(v::AbstractVertex)::String = ismissing(location(v)) ? string(id(v)) : string(location(v))

# The zone name for an edge is derived from the locations of its connected vertices.
# Priority: both locations → same location or "loc1_loc2"; one location → that location;
# no locations → fallback to concatenated vertex IDs
function get_zone_name(e::AbstractEdge)::String
    start_loc = location(e.start_vertex)
    end_loc = location(e.end_vertex)
    
    # Both vertices have locations
    if !ismissing(start_loc) && !ismissing(end_loc)
        return start_loc == end_loc ? string(start_loc) : string("$(start_loc)_$(end_loc)")
    end
    
    # Only one vertex has a location - use it
    !ismissing(start_loc) && return string(start_loc)
    !ismissing(end_loc) && return string(end_loc)
    
    # Neither vertex has a location - fall back to concatenated vertex IDs
    return string("$(id(e.start_vertex))_$(id(e.end_vertex))")
end

# New functions for flow outputs - get node_in and node_out
get_node_in(e::AbstractEdge) = id(e.start_vertex)
get_node_out(e::AbstractEdge) = id(e.end_vertex)

# Define flow signs for different combinations of vertices
get_flow_sign(n1::Node, n2::Node) = 1.0
get_flow_sign(n::Node, s::AbstractStorage) = -1.0
get_flow_sign(n::Node, t::Transformation) = -1.0
get_flow_sign(s::AbstractStorage, n::Node) = 1.0
get_flow_sign(s1::AbstractStorage, s2::AbstractStorage) = 1.0
get_flow_sign(s::AbstractStorage, t::Transformation) = 1.0
get_flow_sign(t::Transformation, n::Node) = 1.0
get_flow_sign(t::Transformation, s::AbstractStorage) = -1.0
get_flow_sign(t1::Transformation, t2::Transformation) = 1.0
# Get flow sign based on which vertex is the start and which is the end
get_flow_sign(e::AbstractEdge) = get_flow_sign(e.start_vertex, e.end_vertex)

# The resource id is the id of the asset that the object belongs to
function get_resource_id(obj::T, asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}) where {T<:Union{AbstractEdge,AbstractStorage}}
    asset = asset_map[id(obj)]
    asset[].id
end
get_resource_id(obj::Node) = id(obj)

# The component id is the id of the object itself
get_component_id(obj::T) where {T<:Union{AbstractEdge,Node,AbstractStorage}} = Symbol("$(id(obj))")

# Get the type of an asset
function get_type(asset::Base.RefValue{<:AbstractAsset})
    asset = asset[]
    type_name = string(typesymbol(typeof(asset)))
    param_names = string.(typesymbol.(typeof(asset).parameters))
    # If the asset has commodities that are parametric, return the type name with the commodities
    if !isempty(param_names)
        return "$type_name{$(join(param_names, ","))}"
    else
        return type_name
    end   
end
# Get the type of a MacroObject
get_type(obj::T) where {T<:Union{AbstractEdge,Node,AbstractStorage}} = string(typeof(obj))

# Get the unit of a MacroObject
get_unit(obj::AbstractEdge, f::Function) = unit(commodity_type(obj.timedata), f)    #TODO: check if this is correct
get_unit(obj::T, f::Function) where {T<:Union{Node,AbstractStorage}} = unit(commodity_type(obj), f)
