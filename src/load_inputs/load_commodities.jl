function commodity_types(m::Module=Macro)
    return all_subtypes(m, :Commodity)
end
  
function load_commodities(path::AbstractString, rel_path::AbstractString)
    path = rel_or_abs_path(path, rel_path)
    if isdir(path)
        path = joinpath(path, "commodities.json")
    end
    # read in the list of commodities from the data directory
    isfile(path) || error("Commodity data not found at $(abspath(path))")
    return load_commodities(JSON3.read(path))
end

function load_commodities(data::AbstractDict{Symbol, Any}, rel_path::AbstractString)
    if haskey(data, :path)
        path = rel_or_abs_path(data[:path], rel_path)
        return load_commodities(path, rel_path)
    else
        return load_commodities(data)
    end
end

function load_commodities(data::AbstractVector{<:AbstractString}, rel_path::AbstractString)
    # Probably means we have a vector of commdity types
    return load_commodities(Symbol.(data))
end

function load_commodities(data::AbstractDict{Symbol, Any})
    # make sure the commodities are valid
    if haskey(data, :commodities)
        return load_commodities(data[:commodities])
    end
    return load_commodities(data[:commodities])
end

load_commodities(commodities::AbstractVector{<:AbstractString}) = load_commodities(Symbol.(commodities))

function load_commodities(commodities::Vector{Symbol})
    # get the list of all commodities available
    macro_commodities = commodity_types()

    validate_commodities(commodities)

    # return a dictionary of commodities Dict{Symbol, DataType}
    filter!(((key,_),) -> key in commodities, macro_commodities)
    return macro_commodities
end


function validate_commodities(commodities, macro_commodities::Dict{Symbol,DataType}=commodity_types(Macro))
    if any(commodity -> commodity ∉ keys(macro_commodities), commodities)
        error("Unknown commodities: $(setdiff(commodities, keys(macro_commodities)))")
    end
    return nothing
end
