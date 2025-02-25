struct FuelsEndUse{T} <: AbstractAsset
    id::AssetId
    fuelsenduse_transform::Transformation
    fuel_edge::Edge{T}
    fuel_demand_edge::Edge{T}
    co2_edge::Edge{CO2}
end

FuelsEndUse(id::AssetId, fuelsenduse_transform::Transformation, fuel_edge::Edge{T}, fuel_demand_edge::Edge{T}, co2_edge::Edge{CO2}) where T<:Commodity =
    FuelsEndUse{T}(id, fuelsenduse_transform, fuel_edge, fuel_demand_edge, co2_edge)

function make(::Type{FuelsEndUse}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    FuelsEndUse_key = :transforms
    transform_data = process_data(data[FuelsEndUse_key])
    fuelsenduse_transform = Transformation(;
        id = Symbol(id, "_", FuelsEndUse_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    fuel_edge_key = :fuel_edge
    fuel_edge_data = process_data(data[:edges][fuel_edge_key])
    T = commodity_types()[Symbol(fuel_edge_data[:type])]
    
    fuel_start_node = find_node(system.locations, Symbol(fuel_edge_data[:start_vertex]))
    fuel_end_node = fuelsenduse_transform
    fuel_edge = Edge(
        Symbol(id, "_", fuel_edge_key),
        fuel_edge_data,
        system.time_data[Symbol(T)],
        T,
        fuel_start_node,
        fuel_end_node,
    )
    fuel_edge.unidirectional = true;

    fuel_demand_edge_key = :fuel_demand_edge
    fuel_demand_edge_data = process_data(data[:edges][fuel_demand_edge_key])
    fuel_demand_start_node = fuelsenduse_transform
    fuel_demand_end_node = find_node(system.locations, Symbol(fuel_demand_edge_data[:end_vertex]))
    fuel_demand_edge = Edge(
        Symbol(id, "_", fuel_demand_edge_key),
        fuel_demand_edge_data,
        system.time_data[Symbol(T)],
        T,
        fuel_demand_start_node,
        fuel_demand_end_node,
    )
    fuel_demand_edge.unidirectional = true;

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = fuelsenduse_transform
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

    fuelsenduse_transform.balance_data = Dict(
        :fuel_demand => Dict(
            fuel_edge.id => 1.0,
            fuel_demand_edge.id => 1.0
        ),
        :emissions => Dict(
            fuel_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0
        )
    )

    return FuelsEndUse(id, fuelsenduse_transform, fuel_edge, fuel_demand_edge, co2_edge) 
end
