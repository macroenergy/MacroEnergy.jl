function template_subcommodity(comm_file::AbstractString, subcommodity::AbstractString, commodity::AbstractString; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    return template_subcommodity(comm_file, [subcommodity], [commodity]; style=style, format=format, make_file=make_file)
end

function template_subcommodity(system::AbstractSystem, subcommodity::AbstractString, commodity::AbstractString; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    comm_file = joinpath(system.data_dirpath, system_data[:commodities][:path])
    return template_subcommodity(comm_file, [subcommodity], [commodity]; style=style, format=format, make_file=make_file)
end

function template_subcommodity(comm_file::AbstractString, subcommodities::Vector{<:AbstractString}, commodity::AbstractString; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    commodities = fill(commodity, length(subcommodities))
    return template_subcommodity(comm_file, subcommodities, commodities; style=style, format=format, make_file=make_file)
end

function template_subcommodity(system::AbstractSystem, subcommodities::Vector{<:AbstractString}, commodity::AbstractString; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    comm_file = joinpath(system.data_dirpath, system_data[:commodities][:path])
    return template_subcommodity(comm_file, subcommodities, commodity; style=style, format=format, make_file=make_file)
end

function get_commodity_names(commodity_list::AbstractVector)
    return String[get_commodity_names(c) for c in commodity_list]
end

function get_commodity_names(commodity::AbstractString)
    return commodity
end

function get_commodity_names(commodity::AbstractDict)
    if haskey(commodity, :name)
        return commodity[:name]
    end
    error("Commodity must be a string or a dictionary with a :name key")
end

function template_subcommodity(comm_file::AbstractString, subcommodities::Vector{<:AbstractString}, commodities::Vector{<:AbstractString}; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    if length(subcommodities) != length(commodities)
        error("Subcommodities and commodities must have the same length\nOr commodities must be a single commodity")
    end
    comm_file = find_file(comm_file, "commodities.json", make_file)
    commodities_file = copy(read_json(comm_file))
    listed_commodities = get_commodity_names(commodities_file[:commodities])
    new_subcommodities = Dict{Symbol,Any}[]
    for (idx, subcommodity) in enumerate(subcommodities)
        commodity = commodities[idx]
        if commodity ∉ listed_commodities
            @warn("Super-commodity $commodity does not exist. Skipping creating $subcommodity")
            continue
        elseif subcommodity in listed_commodities
            @warn("Subcommodity $subcommodity already exists. Skipping creating $subcommodity")
            continue
        end
        # Note: this has to be Dict{Symbol, Any} as that's how the JSON3 
        # parser will read it in. Otherwise, duplicates will be created
        new_subcommodity = Dict{Symbol,Any}(
            :name => subcommodity,
            :acts_like => commodity
        )
        push!(new_subcommodities, new_subcommodity)
    end
    commodities_file[:commodities] = OrderedSet{Any}(commodities_file[:commodities])
    for subc in new_subcommodities
        push!(commodities_file[:commodities], subc)
    end
    if format == "json"
        write_json(comm_file, commodities_file)
    else
        error("Unsupported format: $format. Only json is supported for the commodities file.")
    end
    return nothing
end