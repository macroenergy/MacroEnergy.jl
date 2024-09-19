id(asset::AbstractAsset) = asset.id

"""
    struct_info(t::Type{T}) where T

    Return a vector of tuples with the field names and types of a struct.
"""
function struct_info(::Type{T}, include_id::Bool=false) where T
    if include_id
        names = Base.fieldnames(T)
    else
        names = fieldnames(T)
    end
    return [(names[idx], x) for (idx, x) in enumerate(T.types)]
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

function print_struct_info(info::Vector{Tuple{Symbol, DataType}})
    for (name, type) in info
        println("Field: $name, Type: $type")
    end    
end

