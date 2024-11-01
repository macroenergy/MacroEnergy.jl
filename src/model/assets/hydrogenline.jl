struct HydrogenLine <: AbstractAsset
    id::AssetId
    h2_edge::Edge{Hydrogen}
end

function make(::Type{<:HydrogenLine}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id]) 

    h2_edge_key = :h2_edge
    h2_edge_data = process_data(data[:edges][h2_edge_key])
    h2_start_node = find_node(system.locations, Symbol(h2_edge_data[:start_vertex]))
    h2_end_node = find_node(system.locations, Symbol(h2_edge_data[:end_vertex]))

    h2_edge = Edge(
        Symbol(id, "_", h2_edge_key),
        h2_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_start_node,
        h2_end_node,
    )
    h2_edge.constraints = get(h2_edge_data, :constraints, [CapacityConstraint()])

    h2_edge.loss_fraction = get(h2_edge_data,:line_loss_percentage,0.0)

    return HydrogenLine(id, h2_edge)
end
