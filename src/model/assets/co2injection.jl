struct CO2Injection <: AbstractAsset
    id::AssetId
    co2injection_transform::Transformation
    co2_captured_edge::Edge{CO2Captured}
    co2_storage_edge::Edge{CO2Captured}
end

function make(::Type{CO2Injection}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    co2injection_key = :transforms
    transform_data = process_data(data[co2injection_key])
    co2injection_transform = Transformation(;
        id = Symbol(id, "_", co2injection_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    co2_captured_edge_key = :co2_captured_edge
    co2_captured_edge_data = process_data(data[:edges][co2_captured_edge_key])
    co2_captured_start_node = find_node(system.locations, Symbol(co2_captured_edge_data[:start_vertex]))
    co2_captured_end_node = co2injection_transform
    co2_captured_edge = Edge(
        Symbol(id, "_", co2_captured_edge_key),
        co2_captured_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_captured_start_node,
        co2_captured_end_node,
    )
    co2_captured_edge.constraints = get(co2_captured_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    co2_captured_edge.unidirectional = true;
    co2_captured_edge.has_capacity = false;

    co2_storage_edge_key = :co2_storage_edge
    co2_storage_edge_data = process_data(data[:edges][co2_storage_edge_key])
    co2_storage_start_node = co2injection_transform
    co2_storage_end_node = find_node(system.locations, Symbol(co2_storage_edge_data[:end_vertex]))
    co2_storage_edge = Edge(
        Symbol(id, "_", co2_storage_edge_key),
        co2_storage_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_storage_start_node,
        co2_storage_end_node,
    )
    co2_storage_edge.constraints = Vector{AbstractTypeConstraint}()
    co2_storage_edge.unidirectional = true;
    co2_storage_edge.has_capacity = false;

    co2injection_transform.balance_data = Dict(
        :co2_injection_to_storage => Dict(
            co2_captured_edge.id => 1.0,
            co2_storage_edge.id => 1.0
        )
    )

    return CO2Injection(id, co2injection_transform, co2_captured_edge, co2_storage_edge) 
end
