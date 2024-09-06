function make(::Type{T}, data::Dict{Symbol,Any}, system::System)::T where T <: MacroObject
    return T(data, system)
end