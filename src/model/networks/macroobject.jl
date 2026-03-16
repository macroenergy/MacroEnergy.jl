# function make(::Type{T}, data::Dict{Symbol,Any}, system::System)::T where {T<:MacroObject}
#     return T(data, system)
# end

function Base.getindex(macro_object::MacroObject, key::Symbol)
    return value.(getfield(macro_object, key))
end

function get_components(macro_object::MacroObject)
    return [getfield(macro_object, name) for name in propertynames(macro_object) if name != :id]
end

function get_components_and_names(macro_object::MacroObject)
    return [(getfield(macro_object, name), name) for name in propertynames(macro_object) if name != :id]
end

## Helper/internal functions to extract MacroObjects from System
# E.g., get_macro_objs(system, AbstractEdge)
# E.g., get_macro_objs(asset, AbstractEdge, return_ids_map=true)
# The return_ids_map is used to return a map of the MacroObjects to the asset they belong to
get_macro_objs(system::System, T::Type{<:MacroObject}) = get_macro_objs(system.assets, T)
get_macro_objs(assets::Vector{<:AbstractAsset}, T::Type{<:MacroObject}) =
    reduce(vcat, [get_macro_objs(asset, T) for asset in assets]; init=T[])
function get_macro_objs(asset::AbstractAsset, T::Type{<:MacroObject})
    objects = Vector{T}()
    for field_name in propertynames(asset)
        field_value = getproperty(asset, field_name)
        if isa(field_value, T)
            push!(objects, field_value)
        end
    end
    return objects
end
get_macro_objs_with_map(system::System, T::Type{<:MacroObject}) = get_macro_objs_with_map(system.assets, T)
function get_macro_objs_with_map(assets::Vector{<:AbstractAsset}, T::Type{<:MacroObject})
    all_objects = Vector{Vector{T}}(undef, length(assets))
    asset_obj_map = Dict{Symbol,Base.RefValue{<:AbstractAsset}}()

    for i in eachindex(assets)
        asset = assets[i]
        objects, object_map = get_macro_objs_with_map(asset, T)
        all_objects[i] = objects
        Base.merge!(asset_obj_map, object_map)
    end

    return reduce(vcat, all_objects; init=T[]), asset_obj_map
end
function get_macro_objs_with_map(asset::AbstractAsset, T::Type{<:MacroObject})
    objects = get_macro_objs(asset, T)
    object_map = Dict{Symbol,Base.RefValue{<:AbstractAsset}}(
        obj.id => Ref(asset) for obj in objects
    )
    return objects, object_map
end
