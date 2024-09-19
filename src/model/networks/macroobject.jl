# function make(::Type{T}, data::Dict{Symbol,Any}, system::System)::T where {T<:MacroObject}
#     return T(data, system)
# end

function Base.getindex(macro_object::MacroObject, key::Symbol)
    return value.(getfield(macro_object, key))
end