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
            # using Gurobi

            (system, model) = run_case(@__DIR__);
            # (system, model) = run_case(@__DIR__; optimizer=Gurobi.Optimizer);
            """
        )
    end
    return nothing
end

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

function template_asset(assets_dir::AbstractString, asset_type::Type{T}; asset_name::AbstractString=string(typesymbol(asset_type)), style::AbstractString="full", format::AbstractString="json") where T<:AbstractAsset
    asset_symbol = typesymbol(asset_type)
    asset_data = Dict{Symbol, Any}(
        :type => asset_symbol,
        :instance_data => [default_data(asset_type, Symbol(string(asset_symbol)*"_1"), style)],
    )
    if format == "json"
        filepath = find_available_filepath(joinpath(assets_dir, "$asset_name.json"))
        write_json(filepath, Dict{Symbol,Any}(Symbol(asset_name) => asset_data))
    elseif format == "csv"
        filepath = find_available_filepath(joinpath(assets_dir, "$asset_name.csv"))
        csv_data = json_to_csv(Dict{Symbol,Any}(Symbol(asset_name) => asset_data))
        for (_, data) in csv_data.asset_data
            write_csv(filepath, DataFrame(data))
        end
    else
        error("Unsupported format: $format. Supported formats are $(input_formats())")
    end
    return nothing
end

function template_asset(system::AbstractSystem, asset_type::Type{T}; asset_name::AbstractString=string(typesymbol(asset_type)), style::AbstractString="full", format::AbstractString="json") where T<:AbstractAsset
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    assets_dir = joinpath(system.data_dirpath, system_data[:assets][:path])
    return template_asset(assets_dir, asset_type; asset_name=asset_name, style=style, format=format)
end

function template_asset(assets_dir::AbstractString, asset_types::Vector{T}; asset_names::Vector{String}=string.(asset_types), style::AbstractString="full", format::AbstractString="json") where T <: Union{Type, UnionAll}
    for (idx, asset_type) in enumerate(asset_types)
        template_asset(assets_dir, asset_type; asset_name=asset_names[idx], style=style, format=format)
    end
    return nothing
end

function template_asset(system::AbstractSystem, asset_types::Vector{T}; asset_names::Vector{String}=string.(asset_types), style::AbstractString="full", format::AbstractString="json") where T <: Union{Type, UnionAll}
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    assets_dir = joinpath(system.data_dirpath, system_data[:assets][:path])
    return template_asset(assets_dir, asset_types; asset_names=asset_names, style=style, format=format)
end

function template_node(nodes_file::AbstractString, node_commodity::Type{T}; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true) where T<:Commodity
    return template_node(nodes_file, [node_commodity]; style=style, format=format, make_file=make_file)
end

function template_node(system::AbstractSystem, node_commodity::Type{T}; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true) where T<:Commodity
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    nodes_file = joinpath(system.data_dirpath, system_data[:nodes][:path])
    return template_node(nodes_file, [node_commodity]; style=style, format=format, make_file=make_file)
end

function template_node(nodes_file::AbstractString, node_commodities::Vector{<:Type}; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    if isfile(nodes_file)
        @debug("Reading existing nodes from $nodes_file")
    elseif isfile(joinpath(nodes_file, "nodes.json"))
        nodes_file = joinpath(nodes_file, "nodes.json")
        @debug("Reading existing nodes from $nodes_file")
    elseif make_file
        nodes_file = joinpath(nodes_file, "nodes.json")
        template_nodes_file(nodes_file)
        @debug("Creating new nodes file at $nodes_file")
    else
        @error("Cannot find nodes file ")
        return nothing
    end
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

function template_location(loc_file::AbstractString, location_name::String; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    return template_location(loc_file, [location_name]; style=style, format=format, make_file=make_file)
end

function template_location(system::AbstractSystem, location_name::String; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    loc_file = joinpath(system.data_dirpath, system_data[:locations][:path])
    return template_location(loc_file, [location_name]; style=style, format=format, make_file=make_file)
end

function template_location(loc_file::AbstractString, location_names::Vector{<:AbstractString}; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    if isfile(loc_file)
        @debug("Reading existing locations from $loc_file")
    elseif isfile(joinpath(loc_file, "locations.json"))
        loc_file = joinpath(loc_file, "locations.json")
        @debug("Reading existing locations from $loc_file")
    elseif make_file
        loc_file = joinpath(loc_file, "locations.json")
        template_locations_file(loc_file)
        @debug("Creating new locations file at $loc_file")
    else
        @error("Cannot find locations file ")
        return nothing
    end
    existing_loc = copy(read_json(loc_file))
    for loc_name in location_names
        push!(existing_loc[:locations], loc_name)
    end
    # Ensure unique locations
    existing_loc[:locations] = unique(existing_loc[:locations])
    write_json(loc_file, existing_loc)
    return nothing
end

function template_location(system::AbstractSystem, location_names::Vector{<:AbstractString}; style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    loc_file = joinpath(system.data_dirpath, system_data[:locations][:path])
    return template_location(loc_file, location_names; style=style, format=format, make_file=make_file)
end
