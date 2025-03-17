struct CementPlant_test{T} <: AbstractAsset
    id::AssetId
    cement_transform::Transformation
    fuel_edge::Edge{T}
    cement_edge::Edge{Cement} # Cement produced
    co2_edge::Edge{CO2}
end

CementPlant_test(id::AssetId, cement_transform::Transformation, fuel_edge::Edge{T}, cement_edge::Edge{Cement}, co2_edge::Edge{CO2}) where T<:Commodity =
    CementPlant_test{T}(id, cement_transform, fuel_edge, cement_edge, co2_edge)

function make(::Type{CementPlant_test}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    # Cement Transformation
    cement_key = :transforms
    transform_data = process_data(data[cement_key])
    cement_transform = Transformation(;
        id = Symbol(id, "_", cement_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    # Fuel Edge
    fuel_edge_key = :fuel_edge
    fuel_edge_data = process_data(data[:edges][fuel_edge_key])
    T = commodity_types()[Symbol(fuel_edge_data[:type])];

    fuel_start_node = find_node(system.locations, Symbol(fuel_edge_data[:start_vertex]))
    fuel_end_node = cement_transform
    fuel_edge = Edge(
        Symbol(id, "_", fuel_edge_key),
        fuel_edge_data,
        system.time_data[Symbol(T)],
        T,
        fuel_start_node,
        fuel_end_node,
    )
    fuel_edge.unidirectional = true;

    # Cement Edge
    cement_edge_key = :cement_edge
    cement_edge_data = process_data(data[:edges][cement_edge_key])
    cement_start_node = cement_transform
    cement_end_node = find_node(system.locations, Symbol(cement_edge_data[:end_vertex]))
    cement_edge = Edge(
        Symbol(id, "_", cement_edge_key),
        cement_edge_data,
        system.time_data[:Cement],
        Cement,
        cement_start_node,
        cement_end_node,
    )
    cement_edge.constraints = get(
            cement_edge_data,
            :constraints,
            [
                CapacityConstraint()
            ],
        )
    cement_edge.unidirectional = true;

    # CO2 Edge
    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = cement_transform
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

    # Balance Constraint Values
    cement_transform.balance_data = Dict(
        :fuel_to_cement => Dict(
            fuel_edge.id => 1.0,
            cement_edge.id => get(transform_data, :fuel_cement_rate, 1.0),
            co2_edge.id => 0,
        ),
        :emissions => Dict(
            fuel_edge.id => 0,
            cement_edge.id => get(transform_data, :fuel_emission_rate, 1.0) + get(transform_data, :process_emission_rate, 1.0),
            co2_edge.id => -1.0,
        )
    )


    return CementPlant_test(id, cement_transform, fuel_edge, cement_edge, co2_edge)
end
