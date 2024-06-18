function create_system(nodes::Dict{Symbol,Node}, edges::Dict{Symbol, Edge}, assets::Dict{Symbol,AbstractAsset})
    system = Vector{Union{Node, Edge, AbstractAsset}}()
    # Nodes
    for (_, node) in nodes
        push!(system, node)
    end
    # Edges
    for (_, edge) in edges
        push!(system, edge)
    end
    # Assets
    for (_, asset) in assets
        push!(system, asset)
    end
    return system
end