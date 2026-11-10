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