macro default_new_system_name()
    return quote
        "new_system"
    end
end

macro input_formats()
    return quote
        ["json", "csv"]
    end
end

function find_file(filepath, default_filename, make_file::Bool=true)
    if isfile(filepath)
        @debug("Reading existing file from $filepath")
        return filepath
    elseif isfile(joinpath(filepath, default_filename))
        filepath = joinpath(filepath, default_filename)
        @debug("Reading existing file from $filepath")
        return filepath
    elseif make_file
        filepath = joinpath(filepath, default_filename)
        mkpath(dirname(filepath))
        @debug("Creating new file at $filepath")
        return filepath
    else
        @error("Cannot find file at $filepath")
        return ""
    end
end

function template_nodes_file(filepath::AbstractString)
    write_json(filepath, Dict(:nodes => []))
    return nothing
end

function template_locations_file(filepath::AbstractString)
    write_json(filepath, Dict(:locations => []))
    return nothing
end

function template_commodities_file(filepath::AbstractString)
    commodity_names = collect(keys(commodity_types()))
    write_json(filepath, Dict(:commodities => commodity_names))
    return nothing
end

function template_timedata_file(filepath::AbstractString)
    default_time_data = Dict{Symbol,Any}(
        :TotalHoursModeled => 8760,
        :HoursPerSubperiod => 8760,
        :HoursPerTimeStep => 1,
        :NumberOfSubperiods => 1,
    )
    time_data = Dict{Symbol,Any}()
    for (k, v) in default_time_data
        if k in [:HoursPerSubperiod, :HoursPerTimeStep]
            time_data[k] = Dict{Symbol,Any}(c => v for c in collect(keys(commodity_types())))
        else
            time_data[k] = v
        end
    end
    write_json(filepath, time_data)
end

function template_settings_file(filepath::AbstractString)
    settings = default_settings()
    write_json(filepath, Dict(k => v for (k, v) in zip(keys(settings), settings)))
    return nothing
end

function template_run_file(filepath::AbstractString)
    # Create a run file for the system
    open(filepath, "w") do io
        write(
            io,
            """
            using MacroEnergy
            # using HiGHS

            (case, model) = run_case(@__DIR__);
            # (case, model) = run_case(@__DIR__; optimizer=Gurobi.Optimizer);
            """
        )
    end
    return nothing
end

#region System

function template_system(dirpath::AbstractString, system_name::AbstractString=@default_new_system_name)
    if isdir(dirpath)
        system_path = joinpath(dirpath, system_name)
    else
        if system_name == @default_new_system_name
            system_path = dirpath
        else
            system_path = joinpath(dirpath, system_name)
        end
    end
    mkpath(system_path)

    system_data = copy(load_default_system_data())

    write_json(joinpath(system_path, "system_data.json"), system_data)

    mkpath(joinpath(system_path, "system"))
    mkpath(joinpath(system_path, system_data[:assets][:path]))
    template_nodes_file(joinpath(system_path, system_data[:nodes][:path]))
    template_locations_file(joinpath(system_path, system_data[:locations][:path]))
    template_commodities_file(joinpath(system_path, system_data[:commodities][:path]))
    template_timedata_file(joinpath(system_path, system_data[:time_data][:path]))

    settings_path = joinpath(system_path, system_data[:settings][:path])
    mkpath(dirname(settings_path))
    template_settings_file(settings_path)

    template_run_file(joinpath(system_path, "run.jl"))

    system = empty_system(system_path)

    return system
end

#endregion
#region Assets 

function check_parametric_type(type::UnionAll)
    return (type = type, parameter = nothing,)
end

function check_parametric_type(type::Union{Type, UnionAll})
    if type == type.name.wrapper
        # Non-parametric type
        return (type = type, parameter = nothing,)
    else
        # Parametric type
        return (type = type.name.wrapper, parameter = type.parameters[1],)
    end
    error("Unsupported type: $type")
end

function template_asset(assets_dir::AbstractString, asset_type::Type{T}; asset_name::AbstractString=string(asset_type), existing_asset_ids::Union{AbstractSet{Symbol}, AbstractVector{Symbol}}=asset_ids_from_dir(assets_dir), style::AbstractString="full", format::AbstractString="json") where T<:AbstractAsset
    asset_type_info = check_parametric_type(asset_type)
    asset_type = asset_type_info.type
    asset_symbol = typesymbol(asset_type)
    asset_id = unique_id(Symbol(asset_name), existing_asset_ids)
    asset_data = Dict{Symbol, Any}(
        :type => asset_symbol,
        :instance_data => [default_data(asset_type, asset_id, style)],
    )
    if !isnothing(asset_type_info.parameter)
        asset_commodity = asset_type_info.parameter
        set_commodity!(asset_type, asset_commodity, asset_data[:instance_data][1])
    end
    if lowercase(format) == "json"
        filepath = find_available_filepath(joinpath(assets_dir, "$asset_name.json"))
        write_json(filepath, Dict{Symbol,Any}(Symbol(asset_name) => asset_data))
    elseif lowercase(format) == "csv"
        filepath = find_available_filepath(joinpath(assets_dir, "$asset_name.csv"))
        csv_data = json_to_csv(Dict{Symbol,Any}(Symbol(asset_name) => asset_data))
        for (_, data) in csv_data.asset_data
            write_csv(filepath, DataFrame(data))
        end
    else
        error("Unsupported format: $format. Supported formats are $(@input_formats())")
    end
    return nothing
end

function template_asset(system::AbstractSystem, asset_type::Type{T}; asset_name::AbstractString=string(asset_type), existing_asset_ids::Union{AbstractSet{Symbol}, AbstractVector{Symbol}}=asset_ids_from_dir(system), style::AbstractString="full", format::AbstractString="json") where T<:AbstractAsset
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    assets_dir = joinpath(system.data_dirpath, system_data[:assets][:path])
    return template_asset(assets_dir, asset_type; asset_name=asset_name, existing_asset_ids=existing_asset_ids, style=style, format=format)
end

function template_asset(assets_dir::AbstractString, asset_types::Vector{T}; asset_names::Vector{String}=string.(asset_types), existing_asset_ids::Union{AbstractSet{Symbol}, AbstractVector{Symbol}}=asset_ids_from_dir(assets_dir), style::AbstractString="full", format::AbstractString="json") where T <: Union{Type, UnionAll}
    for (idx, asset_type) in enumerate(asset_types)
        template_asset(assets_dir, asset_type; asset_name=asset_names[idx], existing_asset_ids=existing_asset_ids, style=style, format=format)
    end
    return nothing
end

function template_asset(system::AbstractSystem, asset_types::Vector{T}; asset_names::Vector{String}=string.(asset_types), existing_asset_ids::Union{AbstractSet{Symbol}, AbstractVector{Symbol}}=asset_ids_from_dir(system), style::AbstractString="full", format::AbstractString="json") where T <: Union{Type, UnionAll}
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    assets_dir = joinpath(system.data_dirpath, system_data[:assets][:path])
    return template_asset(assets_dir, asset_types; asset_names=asset_names, existing_asset_ids=existing_asset_ids, style=style, format=format)
end

#endregion
#region Nodes

function template_node(nodes_file::AbstractString, node_commodity::Type{T}; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true) where T<:Commodity
    return template_node(nodes_file, [node_commodity]; style=style, format=format, make_file=make_file)
end

function template_node(system::AbstractSystem, node_commodity::Type{T}; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true) where T<:Commodity
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    nodes_file = joinpath(system.data_dirpath, system_data[:nodes][:path])
    return template_node(nodes_file, [node_commodity]; style=style, format=format, make_file=make_file)
end

function template_node(nodes_file::AbstractString, node_commodities::Vector{<:Type}; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    nodes_file = find_file(nodes_file, "nodes.json", make_file)

    existing_nodes = copy(read_json(nodes_file))
    for node_commodity in node_commodities
        if node_commodity ∉ values(commodity_types())
            @debug("Node commodity $node_commodity not found in commodity types. Skipping...")
            continue
        end
        node_data = Dict{Symbol,Any}(
            :type => typesymbol(node_commodity),
            :instance_data => [node_default_data()]
        )
        push!(existing_nodes[:nodes], node_data)
    end
    write_json(nodes_file, existing_nodes)
    return nothing
end

function template_node(system::AbstractSystem, node_commodities::Vector{<:Type}; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    nodes_file = joinpath(system.data_dirpath, system_data[:nodes][:path])
    return template_node(nodes_file, node_commodities; style=style, format=format, make_file=make_file)
end

#endregion
#region Locations

function template_location(loc_file::AbstractString, location_name::String; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    return template_location(loc_file, [location_name]; style=style, format=format, make_file=make_file)
end

function template_location(system::AbstractSystem, location_name::String; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    loc_file = joinpath(system.data_dirpath, system_data[:locations][:path])
    return template_location(loc_file, [location_name]; style=style, format=format, make_file=make_file)
end

function template_location(loc_file::AbstractString, location_names::Vector{<:AbstractString}; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    loc_file = find_file(loc_file, "locations.json", make_file)
    existing_loc = copy(read_json(loc_file))
    for loc_name in location_names
        push!(existing_loc[:locations], loc_name)
    end
    existing_loc[:locations] = unique(existing_loc[:locations])
    write_json(loc_file, existing_loc)
    return nothing
end

function template_location(system::AbstractSystem, location_names::Vector{<:AbstractString}; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    loc_file = joinpath(system.data_dirpath, system_data[:locations][:path])
    return template_location(loc_file, location_names; style=style, format=format, make_file=make_file)
end

#endregion
#region commodities

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