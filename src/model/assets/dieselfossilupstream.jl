struct DieselFossilUpstream <: AbstractAsset
    id::AssetId
    dieselfossilupstream_transform::Transformation
    diesel_fossil_edge::Edge{Diesel}
    diesel_edge::Edge{Diesel}
    co2_edge::Edge{CO2}
end

function make(::Type{DieselFossilUpstream}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    dieselfossilupstream_key = :transforms
    transform_data = process_data(data[dieselfossilupstream_key])
    dieselfossilupstream_transform = Transformation(;
        id = Symbol(id, "_", dieselfossilupstream_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    diesel_fossil_edge_key = :diesel_fossil_edge
    diesel_fossil_edge_data = process_data(data[:edges][diesel_fossil_edge_key])
    diesel_fossil_start_node = find_node(system.locations, Symbol(diesel_fossil_edge_data[:start_vertex]))
    diesel_fossil_end_node = dieselfossilupstream_transform
    diesel_fossil_edge = Edge(
        Symbol(id, "_", diesel_fossil_edge_key),
        diesel_fossil_edge_data,
        system.time_data[:Diesel],
        Diesel,
        diesel_fossil_start_node,
        diesel_fossil_end_node,
    )
    diesel_fossil_edge.constraints = get(diesel_fossil_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    diesel_fossil_edge.unidirectional = true;
    diesel_fossil_edge.has_capacity = false;

    diesel_edge_key = :diesel_edge
    diesel_edge_data = process_data(data[:edges][diesel_edge_key])
    diesel_start_node = dieselfossilupstream_transform
    diesel_end_node = find_node(system.locations, Symbol(diesel_edge_data[:end_vertex]))
    diesel_edge = Edge(
        Symbol(id, "_", diesel_edge_key),
        diesel_edge_data,
        system.time_data[:Diesel],
        Diesel,
        diesel_start_node,
        diesel_end_node,
    )
    diesel_edge.constraints = Vector{AbstractTypeConstraint}()
    diesel_edge.unidirectional = true;
    diesel_edge.has_capacity = false;

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = dieselfossilupstream_transform
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

    dieselfossilupstream_transform.balance_data = Dict(
        :diesel => Dict(
            diesel_fossil_edge.id => 1.0,
            diesel_edge.id => 1.0
        ),
        :emissions => Dict(
            diesel_fossil_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0
        )
    )

    return DieselFossilUpstream(id, dieselfossilupstream_transform, diesel_fossil_edge, diesel_edge, co2_edge) 
end
