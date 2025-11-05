"""
Common helper functions for output generation.
"""

# Get the commodity type of a MacroObject
get_commodity_name(obj::AbstractEdge) = typesymbol(commodity_type(obj))
get_commodity_name(obj::Node) = typesymbol(commodity_type(obj))
get_commodity_name(obj::Storage) = typesymbol(commodity_type(obj))

# The commodity subtype is an identifier for the field names
# e.g., "capacity" for capacity variables, "flow" for flow variables, etc.
function get_commodity_subtype(f::Function)
    field_name = Symbol(f)
    if any(field_name .== (:capacity, :new_capacity, :retired_capacity, :existing_capacity, :retrofitted_capacity))
        return :capacity
    # elseif f == various cost # TODO: implement this
    #     return :cost
    else
        return field_name
    end
end

# Get the zone name/location of a vertex
get_zone_name(v::AbstractVertex) = id(v)

# The default zone name for an edge is the concatenation of the ids of its nodes:
# e.g., "elec_1_elec_2" for an edge connecting nodes "elec_1" and "elec_2" or 
# "elec_1" if connecting a node to storage/transformation
function get_zone_name(e::AbstractEdge)
    region_name = join((id(n) for n in (e.start_vertex, e.end_vertex) if isa(n, Node)), "_")
    if isempty(region_name)
        region_name = :internal # edge not connecting nodes
    end
    Symbol(region_name)
end

# New functions for flow outputs - get node_in and node_out
get_node_in(e::AbstractEdge) = id(e.start_vertex)
get_node_out(e::AbstractEdge) = id(e.end_vertex)

# The resource id is the id of the asset that the object belongs to
function get_resource_id(obj::T, asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}) where {T<:Union{AbstractEdge,Storage}}
    asset = asset_map[id(obj)]
    asset[].id
end
get_resource_id(obj::Node) = id(obj)

# The component id is the id of the object itself
get_component_id(obj::T) where {T<:Union{AbstractEdge,Node,Storage}} = Symbol("$(id(obj))")

# Get the type of an asset
get_type(asset::Base.RefValue{<:AbstractAsset}) = Symbol(typeof(asset).parameters[1])
# Get the type of a MacroObject
get_type(obj::T) where {T<:Union{AbstractEdge,Node,Storage}} = Symbol(typeof(obj))

# Get the unit of a MacroObject
get_unit(obj::AbstractEdge, f::Function) = unit(commodity_type(obj.timedata), f)    #TODO: check if this is correct
get_unit(obj::T, f::Function) where {T<:Union{Node,Storage}} = unit(commodity_type(obj), f)
