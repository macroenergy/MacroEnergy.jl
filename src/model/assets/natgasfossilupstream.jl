struct NaturalGasFossilUpstream <: AbstractAsset
    id::AssetId
    natgasfossilupstream_transform::Transformation
    ng_fossil_edge::Edge{NaturalGas}
    ng_edge::Edge{NaturalGas}
    co2_edge::Edge{CO2}
end

function make(::Type{NaturalGasFossilUpstream}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    natgasfossilupstream_key = :transforms
    transform_data = process_data(data[natgasfossilupstream_key])
    natgasfossilupstream_transform = Transformation(;
        id = Symbol(id, "_", natgasfossilupstream_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    ng_fossil_edge_key = :ng_fossil_edge
    ng_fossil_edge_data = process_data(data[:edges][ng_fossil_edge_key])
    ng_fossil_start_node = find_node(system.locations, Symbol(ng_fossil_edge_data[:start_vertex]))
    ng_fossil_end_node = natgasfossilupstream_transform
    ng_fossil_edge = Edge(
        Symbol(id, "_", ng_fossil_edge_key),
        ng_fossil_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        ng_fossil_start_node,
        ng_fossil_end_node,
    )
    ng_fossil_edge.constraints = get(ng_fossil_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    ng_fossil_edge.unidirectional = true;
    ng_fossil_edge.has_capacity = false;

    ng_edge_key = :ng_edge
    ng_edge_data = process_data(data[:edges][ng_edge_key])
    ng_start_node = natgasfossilupstream_transform
    ng_end_node = find_node(system.locations, Symbol(ng_edge_data[:end_vertex]))
    ng_edge = Edge(
        Symbol(id, "_", ng_edge_key),
        ng_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        ng_start_node,
        ng_end_node,
    )
    ng_edge.constraints = Vector{AbstractTypeConstraint}()
    ng_edge.unidirectional = true;
    ng_edge.has_capacity = false;

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = natgasfossilupstream_transform
    co2_end_node = find_node(system.locations, Symbol(co2_edge_data[:end_vertex]))
    co2_edge = Edge(
        Symbol(id, "_", co2_edge_key),
        co2_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_start_node,
        co2_end_node,
    )
    co2_edge.constraints = Vector{AbstractTypeConstraint}()
    co2_edge.unidirectional = true;
    co2_edge.has_capacity = false;

    natgasfossilupstream_transform.balance_data = Dict(
        :ng => Dict(
            ng_fossil_edge.id => 1.0,
            ng_edge.id => 1.0
        ),
        :emissions => Dict(
            ng_fossil_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0
        )
    )

    return NaturalGasFossilUpstream(id, natgasfossilupstream_transform, ng_fossil_edge, ng_edge, co2_edge) 
end
