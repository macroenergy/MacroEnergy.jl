struct FossilFuelsUpstream{T} <: AbstractAsset
    id::AssetId
    fossilfuelsupstream_transform::Transformation
    fossil_fuel_edge::Edge{T}
    fuel_edge::Edge{T}
    co2_edge::Edge{CO2}
end

FossilFuelsUpstream(id::AssetId, fossilfuelsupstream_transform::Transformation, fossil_fuel_edge::Edge{T}, fuel_edge::Edge{T}, co2_edge::Edge{CO2}) where T<:Commodity =
    FossilFuelsUpstream{T}(id, fossilfuelsupstream_transform, fossil_fuel_edge, fuel_edge, co2_edge)

function make(::Type{FossilFuelsUpstream}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    fuelfossilupstream_key = :transforms
    transform_data = process_data(data[fuelfossilupstream_key])
    fossilfuelsupstream_transform = Transformation(;
        id = Symbol(id, "_", fuelfossilupstream_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    fossil_fuel_edge_key = :fossil_fuel_edge
    fossil_fuel_edge_data = process_data(data[:edges][fossil_fuel_edge_key])
    T = commodity_types()[Symbol(fossil_fuel_edge_data[:type])]
    
    fossil_fuel_start_node = find_node(system.locations, Symbol(fossil_fuel_edge_data[:start_vertex]))
    fossil_fuel_end_node = fossilfuelsupstream_transform
    fossil_fuel_edge = Edge(
        Symbol(id, "_", fossil_fuel_edge_key),
        fossil_fuel_edge_data,
        system.time_data[Symbol(T)],
        T,
        fossil_fuel_start_node,
        fossil_fuel_end_node,
    )
    fossil_fuel_edge.unidirectional = true;

    fuel_edge_key = :fuel_edge
    fuel_edge_data = process_data(data[:edges][fuel_edge_key])
    fuel_start_node = fossilfuelsupstream_transform
    fuel_end_node = find_node(system.locations, Symbol(fuel_edge_data[:end_vertex]))
    fuel_edge = Edge(
        Symbol(id, "_", fuel_edge_key),
        fuel_edge_data,
        system.time_data[Symbol(T)],
        T,
        fuel_start_node,
        fuel_end_node,
    )
    fuel_edge.unidirectional = true;

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = fossilfuelsupstream_transform
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

    fossilfuelsupstream_transform.balance_data = Dict(
        :fuel => Dict(
            fossil_fuel_edge.id => 1.0,
            fuel_edge.id => 1.0
        ),
        :emissions => Dict(
            fossil_fuel_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0
        )
    )

    return FossilFuelsUpstream(id, fossilfuelsupstream_transform, fossil_fuel_edge, fuel_edge, co2_edge) 
end
