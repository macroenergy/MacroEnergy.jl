struct DieselEndUse <: AbstractAsset
    id::AssetId
    dieselenduse_transform::Transformation
    diesel_edge::Edge{Diesel}
    diesel_demand_edge::Edge{Diesel}
    co2_edge::Edge{CO2}
end

function make(::Type{DieselEndUse}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    dieselenduse_key = :transforms
    transform_data = process_data(data[dieselenduse_key])
    dieselenduse_transform = Transformation(;
        id = Symbol(id, "_", dieselenduse_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    diesel_edge_key = :diesel_edge
    diesel_edge_data = process_data(data[:edges][diesel_edge_key])
    diesel_start_node = find_node(system.locations, Symbol(diesel_edge_data[:start_vertex]))
    diesel_end_node = dieselenduse_transform
    diesel_edge = Edge(
        Symbol(id, "_", diesel_edge_key),
        diesel_edge_data,
        system.time_data[:Diesel],
        Diesel,
        diesel_start_node,
        diesel_end_node,
    )
    diesel_edge.constraints = get(diesel_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    diesel_edge.unidirectional = true;
    diesel_edge.has_capacity = false;

    diesel_demand_edge_key = :diesel_demand_edge
    diesel_demand_edge_data = process_data(data[:edges][diesel_demand_edge_key])
    diesel_demand_start_node = dieselenduse_transform
    diesel_demand_end_node = find_node(system.locations, Symbol(diesel_demand_edge_data[:end_vertex]))
    diesel_demand_edge = Edge(
        Symbol(id, "_", diesel_demand_edge_key),
        diesel_demand_edge_data,
        system.time_data[:Diesel],
        Diesel,
        diesel_demand_start_node,
        diesel_demand_end_node,
    )
    diesel_demand_edge.constraints = Vector{AbstractTypeConstraint}()
    diesel_demand_edge.unidirectional = true;
    diesel_demand_edge.has_capacity = false;

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = dieselenduse_transform
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

    dieselenduse_transform.balance_data = Dict(
        :diesel_demand => Dict(
            diesel_edge.id => 1.0,
            diesel_demand_edge.id => 1.0
        ),
        :emissions => Dict(
            diesel_edge.id => get(transform_data, :emission_rate, 1.0),
            co2_edge.id => 1.0
        )
    )

    return DieselEndUse(id, dieselenduse_transform, diesel_edge, diesel_demand_edge, co2_edge) 
end
