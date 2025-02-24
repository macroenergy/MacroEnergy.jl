struct GasolineFossilUpstream <: AbstractAsset
    id::AssetId
    gasolinefossilupstream_transform::Transformation
    gasoline_fossil_edge::Edge{Gasoline}
    gasoline_edge::Edge{Gasoline}
    co2_edge::Edge{CO2}
end

function make(::Type{GasolineFossilUpstream}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    gasolinefossilupstream_key = :transforms
    transform_data = process_data(data[gasolinefossilupstream_key])
    gasolinefossilupstream_transform = Transformation(;
        id = Symbol(id, "_", gasolinefossilupstream_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    gasoline_fossil_edge_key = :gasoline_fossil_edge
    gasoline_fossil_edge_data = process_data(data[:edges][gasoline_fossil_edge_key])
    gasoline_fossil_start_node = find_node(system.locations, Symbol(gasoline_fossil_edge_data[:start_vertex]))
    gasoline_fossil_end_node = gasolinefossilupstream_transform
    gasoline_fossil_edge = Edge(
        Symbol(id, "_", gasoline_fossil_edge_key),
        gasoline_fossil_edge_data,
        system.time_data[:Gasoline],
        Gasoline,
        gasoline_fossil_start_node,
        gasoline_fossil_end_node,
    )
    gasoline_fossil_edge.constraints = get(gasoline_fossil_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    gasoline_fossil_edge.unidirectional = true;
    gasoline_fossil_edge.has_capacity = false;

    gasoline_edge_key = :gasoline_edge
    gasoline_edge_data = process_data(data[:edges][gasoline_edge_key])
    gasoline_start_node = gasolinefossilupstream_transform
    gasoline_end_node = find_node(system.locations, Symbol(gasoline_edge_data[:end_vertex]))
    gasoline_edge = Edge(
        Symbol(id, "_", gasoline_edge_key),
        gasoline_edge_data,
        system.time_data[:Gasoline],
        Gasoline,
        gasoline_start_node,
        gasoline_end_node,
    )
    gasoline_edge.constraints = Vector{AbstractTypeConstraint}()
    gasoline_edge.unidirectional = true;
    gasoline_edge.has_capacity = false;

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = gasolinefossilupstream_transform
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

    gasolinefossilupstream_transform.balance_data = Dict(
        :gasoline => Dict(
            gasoline_fossil_edge.id => 1.0,
            gasoline_edge.id => 1.0
        ),
        :emissions => Dict(
            gasoline_fossil_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0
        )
    )

    return GasolineFossilUpstream(id, gasolinefossilupstream_transform, gasoline_fossil_edge, gasoline_edge, co2_edge) 
end
