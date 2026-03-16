function all_subtypes(m::Module, type::Symbol)::Dict{Symbol,DataType}
    types = Dict{Symbol,DataType}()
    for subtype in subtypes(getfield(m, type))
        all_subtypes!(types, subtype)
    end
    return types
end

function all_subtypes!(types::Dict{Symbol,DataType}, type::DataType)
    types[typesymbol(type)] = type
    if !isempty(subtypes(type))
        for subtype in subtypes(type)
            all_subtypes!(types, subtype)
        end
    end
    return nothing
end

function all_subtypes!(types::Dict{Symbol,DataType}, type::UnionAll)
    return all_subtypes!(types, Base.unwrap_unionall(type))
end

function typesymbol(type::DataType)
    return Base.typename(type).name
end

function typesymbol(type::UnionAll)
    return Base.typename(type).name
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

function rel_or_abs_path(path::T, rel_dir::T = pwd())::String where {T<:AbstractString}
    if ispath(path)
        return path
    elseif ispath(joinpath(rel_dir, path))
        return joinpath(rel_dir, path)
    else
        return path
        # throw(ArgumentError("File $path not found"))
    end
end

recursive_merge(x::AbstractDict...) = merge(recursive_merge, x...)
recursive_merge(x::AbstractVector...) = cat(x...; dims = 1)
recursive_merge(x...) = x[end]

recursive_merge!(x::AbstractDict...) = merge!(recursive_merge!, x...)
recursive_merge!(x::AbstractVector...) = cat(x...; dims = 1)
recursive_merge!(x...) = x[end]

###### ###### ###### ###### ###### ######

function get_from(dict::T, keys::Vector{Symbol}, default) where T<:AbstractDict{Symbol, Any}
    for key in keys
        if haskey(dict, key)
            return get(dict, key, default)
        end
    end
    return default
end

function get_from(dicts::Vector{T}, key::Symbol, default) where T<:AbstractDict{Symbol, Any}
    for dict in dicts
        if haskey(dict, key)
            return get(dict, key, default)
        end
    end
    return default
end

function get_from(dicts::Vector{T}, keys::Vector{Symbol}, default) where T<:AbstractDict{Symbol, Any}
    for dict in dicts
        for key in keys
            if haskey(dict, key)
                return get(dict, key, default)
            end
        end
    end
    return default
end

function get_from(combos::Vector{Tuple{T, Symbol}}, default) where T<:AbstractDict{Symbol, Any}
    for (dict, key) in combos
        if haskey(dict, key)
            return get(dict, key, default)
        end
    end
    return default
end

function check_default(value, default)
    return value == default
end

function check_default(dict::AbstractDict, default)
    return all(values(dict) .== default)
end

function check_default(value, default::Missing)
    return ismissing(value)
end

function check_default(dict::AbstractDict, default::Missing)
    return all(ismissing.(values(dict)))
end

function get_from(combos::Vector{Tuple{T, Symbol}}, default, returnmissing::Bool) where T<:AbstractDict{Symbol, Any}
    for (dict, key) in combos
        if haskey(dict, key)
            value = get(dict, key, default)
            if !returnmissing && check_default(value, default)
                continue
            end
            return get(dict, key, default)
        end
    end
    return default
end

###### ###### ###### ###### ###### ######

function chained_get(d::Dict{Symbol,Any}, key_chain::Tuple{Vararg{Symbol}}, default=missing)
    if length(key_chain) == 1
        return get(d, key_chain[1], default)
    else
        if haskey(d, key_chain[1])
            return chained_get(d[key_chain[1]], key_chain[2:end], default)
        else
            return default
        end
    end
end

function chained_get(combos::Vector{Tuple{Dict{Symbol,Any}, Tuple{Vararg{Symbol}}}}, default=missing)
    for (dict, key_chain) in combos
        temp = chained_get(dict, key_chain, default)
        if temp != default
            return temp
        end
    end
    return default
end

###### ###### ###### ###### ###### ######

function replace_first_arg(expr::Expr, new_arg::Symbol)
    return Expr(expr.head, replace_first_arg(expr.args[1], new_arg), expr.args[2:end]...)
end

function replace_first_arg(expr::Symbol, new_arg::Symbol)
    return new_arg
end

macro setup_data(type, data, id)
    return esc(quote
        data = recursive_merge(clear_dict(default_data($type, $id, "full")), $data)
        defaults = default_data($type, $id, "full")
    end)
end

macro process_data(name, data, get_from_tuples)
    if isa(data, Symbol)
        defaults_name = :defaults
    elseif isa(data, Expr)
        defaults_name = replace_first_arg(data, :defaults) 
    end
    return esc(quote
        local loaded_data = Dict{Symbol,Any}(
            key => get_from($get_from_tuples, missing, false) for key in keys($data)
        )
        # Remove "missing" values to just get the loaded data
        remove_missing!(loaded_data)
        # Merge the loaded data into the original user-provided data
        # This should mean any simplified inputs are now in 
        # their fully-specified positions
        merge!($data, loaded_data)
        remove_missing!($data)
        # We can't recursive_merge! the dicts, as it will keep
        # both copies of some kinds of data.
        # But we do want to keep both copies of the constraints.
        # Therefore, we recursive_merge! the constraints, and then
        # merge the rest of the data.
        if haskey($data, :constraints)
            recursive_merge!($defaults_name[:constraints], $data[:constraints])
            $data[:constraints] = $defaults_name[:constraints]
        end
        merge!($defaults_name, $data)
        $name = process_data($defaults_name)
    end)
end

function clear_dict(dict)
    for (key, value) in dict
        if isa(value, Dict{Symbol,Any})
            clear_dict(value)
        elseif isa(value, Dict{Symbol,Bool})
            # for k in keys(value)
            #     value[k] = missing
            # end
            dict[key] = missing
        else
            dict[key] = missing
        end
    end
    return dict
end

macro start_vertex(name, data, commodity, get_from_tuples)
    return esc(quote
        local vertex = get_from($get_from_tuples, missing, false)
        $data[:start_vertex] = vertex
        $name = find_node(system, Symbol(vertex), $commodity)
    end)
end

macro end_vertex(name, data, commodity, get_from_tuples)
    return esc(quote
        local vertex = get_from($get_from_tuples, missing, false)
        $data[:end_vertex] = vertex
        $name = find_node(system, Symbol(vertex), $commodity)
    end)
end
