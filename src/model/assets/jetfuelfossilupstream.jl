struct JetFuelFossilUpstream <: AbstractAsset
    id::AssetId
    jetfuelfossilupstream_transform::Transformation
    jetfuel_fossil_edge::Edge{JetFuel}
    jetfuel_edge::Edge{JetFuel}
    co2_edge::Edge{CO2}
end

function make(::Type{JetFuelFossilUpstream}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    jetfuelfossilupstream_key = :transforms
    transform_data = process_data(data[jetfuelfossilupstream_key])
    jetfuelfossilupstream_transform = Transformation(;
        id = Symbol(id, "_", jetfuelfossilupstream_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    jetfuel_fossil_edge_key = :jetfuel_fossil_edge
    jetfuel_fossil_edge_data = process_data(data[:edges][jetfuel_fossil_edge_key])
    jetfuel_fossil_start_node = find_node(system.locations, Symbol(jetfuel_fossil_edge_data[:start_vertex]))
    jetfuel_fossil_end_node = jetfuelfossilupstream_transform
    jetfuel_fossil_edge = Edge(
        Symbol(id, "_", jetfuel_fossil_edge_key),
        jetfuel_fossil_edge_data,
        system.time_data[:JetFuel],
        JetFuel,
        jetfuel_fossil_start_node,
        jetfuel_fossil_end_node,
    )
    jetfuel_fossil_edge.constraints = get(jetfuel_fossil_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    jetfuel_fossil_edge.unidirectional = true;
    jetfuel_fossil_edge.has_capacity = false;

    jetfuel_edge_key = :jetfuel_edge
    jetfuel_edge_data = process_data(data[:edges][jetfuel_edge_key])
    jetfuel_start_node = jetfuelfossilupstream_transform
    jetfuel_end_node = find_node(system.locations, Symbol(jetfuel_edge_data[:end_vertex]))
    jetfuel_edge = Edge(
        Symbol(id, "_", jetfuel_edge_key),
        jetfuel_edge_data,
        system.time_data[:JetFuel],
        JetFuel,
        jetfuel_start_node,
        jetfuel_end_node,
    )
    jetfuel_edge.constraints = Vector{AbstractTypeConstraint}()
    jetfuel_edge.unidirectional = true;
    jetfuel_edge.has_capacity = false;

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = jetfuelfossilupstream_transform
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

    jetfuelfossilupstream_transform.balance_data = Dict(
        :jetfuel => Dict(
            jetfuel_fossil_edge.id => 1.0,
            jetfuel_edge.id => 1.0
        ),
        :emissions => Dict(
            jetfuel_fossil_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0
        )
    )

    return JetFuelFossilUpstream(id, jetfuelfossilupstream_transform, jetfuel_fossil_edge, jetfuel_edge, co2_edge) 
end
