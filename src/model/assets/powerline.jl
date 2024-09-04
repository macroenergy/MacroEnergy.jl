struct PowerLine <: AbstractAsset
    id::AssetId
    elec_edge::Edge{Electricity}
end
id(b::PowerLine) = b.id

function make(::Type{<:PowerLine}, data::AbstractDict{Symbol, Any}, system::System)
    elec_edge_data = process_data(data[:edges][:elec_edge])

    id = AssetId(elec_edge_data[:id])   # TODO: check if this should be in data instead

    elec_start_node = find_node(system.locations, Symbol(elec_edge_data[:start_vertex]))
    elec_end_node = find_node(system.locations, Symbol(elec_edge_data[:end_vertex]))

    elec_edge = Edge(Symbol("E_"*elec_edge_data[:id]),elec_edge_data, system.time_data[:Electricity],Electricity, elec_start_node,  elec_end_node);
    elec_edge.constraints = get(elec_edge_data, :constraints, [CapacityConstraint()])

    return PowerLine(id, elec_edge)
end
