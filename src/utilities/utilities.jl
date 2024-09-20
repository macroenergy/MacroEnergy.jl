function all_subtypes(m::Module, type::Symbol)::Dict{Symbol,DataType}
    types = Dict{Symbol,DataType}()
    for subtype in subtypes(getfield(m, type))
        all_subtypes!(types, subtype)
    end
    return types
end

function all_subtypes!(types::Dict{Symbol,DataType}, type::DataType)
    types[Symbol(type)] = type
    if !isempty(subtypes(type))
        for subtype in subtypes(type)
            all_subtypes!(types, subtype)
        end
    end
    return nothing
end

function fieldnames(type::T) where {T<:Type{<:AbstractAsset}}
    return filter(x -> x != :id, Base.fieldnames(type))
end

###### ###### ###### ###### ###### ######
# Functions to check whether a path is relative or absolute, relative to a given directory
# Some of this might be unnecessary, as Julia does some of it automatically 
# to the current working directory

# However, I haven't tested it on all OS, and this lets us 
# set out own "root" directory

# We might need to swap the default behaviour to use the
# path relative to rel_dir
###### ###### ###### ###### ###### ######

function rel_or_abs_path(path::T, rel_dir::T = pwd())::T where {T<:AbstractString}
    if ispath(path)
        return path
    elseif ispath(joinpath(rel_dir, path))
        return joinpath(rel_dir, path)
    else
        return path
        # throw(ArgumentError("File $path not found"))
    end
end