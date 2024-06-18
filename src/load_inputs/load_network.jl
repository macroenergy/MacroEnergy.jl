function load_edges_json(data_dir::AbstractString, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    commodities = commodity_types()
    # Make a list of all the .JSON files in the data directory
    # files = filter(x -> endswith(x, ".json"), readdir(data_dir))
    files = ["edges.json"]
    # Make an empty dictionary of edges
    edges = Dict{Symbol, Edge}()
    for file in files
        data = JSON3.read(joinpath(data_dir, file))
        load_edges!(edges, data, commodities, time_data, nodes)
    end
    return edges
end

function load_edges!(edges::Dict{Symbol, Edge}, data::AbstractDict{Symbol,Any}, commodity_types::Dict{Symbol,DataType}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    for (e_name, e_data) in data
        sanitize_json!(e_data)
        e_type = commodity_types[Symbol(e_data[:type])]
        if typeof(e_data[:instance]) == JSON3.Object
            # Only one instance
            instance_data = edge_instance_data(e_data[:global], e_data[:instance])
            haskey(instance_data, :id) ? instance_id = Symbol(instance_data[:id]) : instance_id = e_name
            instance_data[:id], _ = make_edge_id(instance_id, edges)
            start_node = nodes[Symbol(instance_data[:start_node_id])]
            end_node = nodes[Symbol(instance_data[:end_node_id])]
            edges[instance_data[:id]] = Edge(instance_data, time_data, e_type, node_start, node_end)
        else
            # Multiple instances
            # Note, the edge instance data has a different structures
            # than the transformation data.
            for (instance_idx, instance_data) in enumerate(e_data[:instance])
                instance_data = edge_instance_data(e_data[:global], instance_data)
                haskey(instance_data, :id) ? instance_id = Symbol(instance_data[:id]) : instance_id = default_edge_name(instance_idx, e_name)
                instance_data[:id], _ = make_edge_id(instance_id, edges)
                start_node = nodes[Symbol(instance_data[:start_node_id])]
                end_node = nodes[Symbol(instance_data[:end_node_id])]
                edges[instance_data[:id]] = Edge(instance_data, time_data, e_type, start_node, end_node)
            end
        end
    end
end

function default_edge_name(instance_name::T, e_name::T) where T<:Union{AbstractString,Symbol}
    Symbol(string(instance_name, "_", e_name))
end

function default_edge_name(instance_idx::Int, e_name::T) where T<:Union{AbstractString,Symbol}
    Symbol(string("z", instance_idx, "_", e_name))
end

function edge_instance_data(global_data::AbstractDict{Symbol,Any}, instance_data::T) where T<:AbstractDict{Symbol,Any}
    instance_data = merge(global_data, instance_data)

    validate_data!(instance_data)
    return instance_data
end

function make_edge_id(id::Symbol, edges::Dict{Symbol, Edge}, count::UInt8=UInt8(1))
    existing_ids = collect(keys(edges))
    # Unlike the transformations, we won't add a count by default
    if !(id in existing_ids)
        return id, count
    end
    # Otherwise, keep incrementing the count till we find a unique ID
    while Symbol(string(id, "_", count)) in existing_ids
        count += UInt8(1)
    end
    return Symbol(string(id, "_", count)), count
end

function load_nodes_json(data_dir::AbstractString, time_data::Dict{Symbol,TimeData})
    commodities = commodity_types()
    # Make a list of all the .JSON files in the data directory
    # files = filter(x -> endswith(x, ".json"), readdir(data_dir))
    files = ["nodes.json"]
    # Make an empty dictionary of nodes
    nodes = Dict{Symbol, Node}()
    for file in files
        data = JSON3.read(joinpath(data_dir, file))
        load_nodes!(nodes, data, commodities, time_data)
    end
    return nodes
end

function load_nodes!(nodes::Dict{Symbol, Node}, data::AbstractDict{Symbol,Any}, commodity_types::Dict{Symbol,DataType}, time_data::Dict{Symbol,TimeData})
    for (n_name, n_data) in data
        sanitize_json!(n_data)
        n_type = commodity_types[Symbol(n_data[:type])]
        if typeof(n_data[:instance]) == JSON3.Object
            # Only one instance
            instance_data = node_instance_data(n_data[:global], n_data[:instance])
            haskey(instance_data, :id) ? instance_id = Symbol(instance_data[:id]) : instance_id = n_name
            instance_data[:id], _ = make_node_id(instance_id, nodes)
            nodes[instance_data[:id]] = Node(instance_data, time_data, n_type)
        else
            # Multiple instances
            # Note, the node instance data has a different structures
            # than the transformation data.
            for (instance_idx, instance_data) in enumerate(n_data[:instance])
                instance_data = node_instance_data(n_data[:global], instance_data)
                haskey(instance_data, :id) ? instance_id = Symbol(instance_data[:id]) : instance_id = default_node_name(instance_idx, n_name)
                instance_data[:id], _ = make_node_id(instance_id, nodes)
                nodes[instance_data[:id]] = Node(instance_data, time_data, n_type)
            end
        end
    end
end

function default_node_name(instance_name::T, n_name::T) where T<:Union{AbstractString,Symbol}
    Symbol(string(instance_name, "_", n_name))
end

function default_node_name(instance_idx::Int, n_name::T) where T<:Union{AbstractString,Symbol}
    Symbol(string("z", instance_idx, "_", n_name))
end

function node_instance_data(global_data::AbstractDict{Symbol,Any}, instance_data::T) where T<:AbstractDict{Symbol,Any}
    instance_data = merge(global_data, instance_data)

    validate_data!(instance_data)
    return instance_data
end

function node_instance_data(global_data::AbstractDict{Symbol,Any}, instance_data::T) where T<:Dict{Symbol,Any}
    instance_data = merge(global_data, instance_data)

    validate_data!(instance_data)
    return instance_data
end


function make_node_id(id::Symbol, nodes::Dict{Symbol, Node}, count::UInt8=UInt8(1))
    existing_ids = collect(keys(nodes))
    # Unlike the transformations, we won't add a count by default
    if !(id in existing_ids)
        return id, count
    end
    # Otherwise, keep incrementing the count till we find a unique ID
    while Symbol(string(id, "_", count)) in existing_ids
        count += UInt8(1)
    end
    return Symbol(string(id, "_", count)), count
end
