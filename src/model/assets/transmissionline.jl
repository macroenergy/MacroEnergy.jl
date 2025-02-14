struct TransmissionLine{T} <: AbstractAsset
    id::AssetId
    t_edge::Edge{T}
end

TransmissionLine(id::AssetId, t_edge::Edge{T}) where T<:Commodity =
TransmissionLine{T}(id,t_edge)

function make(::Type{<:TransmissionLine}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id]) 

    t_edge_key = :t_edge
    t_edge_data = process_data(data[:edges][t_edge_key])
    T = commodity_types()[Symbol(t_edge_data[:commodity])];
    t_start_node = find_node(system.locations, Symbol(t_edge_data[:start_vertex]))
    t_end_node = find_node(system.locations, Symbol(t_edge_data[:end_vertex]))

    t_edge = Edge(
        Symbol(id, "_", t_edge_key),
        t_edge_data,
        system.time_data[Symbol(T)],
        T,
        t_start_node,
        t_end_node,
    )
    t_edge.constraints = get(t_edge_data, :constraints, [CapacityConstraint()])

    t_edge.loss_fraction = get(t_edge_data,:line_loss_percentage,0.0)

    return TransmissionLine(id, t_edge)
end