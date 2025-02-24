struct GasolineEndUse <: AbstractAsset
    id::AssetId
    GasolineEndUse_transform::Transformation
    gasoline_edge::Edge{Gasoline}
    gasoline_demand_edge::Edge{Gasoline}
    co2_edge::Edge{CO2}
end

function make(::Type{GasolineEndUse}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    GasolineEndUse_key = :transforms
    transform_data = process_data(data[GasolineEndUse_key])
    GasolineEndUse_transform = Transformation(;
        id = Symbol(id, "_", GasolineEndUse_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    gasoline_edge_key = :gasoline_edge
    gasoline_edge_data = process_data(data[:edges][gasoline_edge_key])
    gasoline_start_node = find_node(system.locations, Symbol(gasoline_edge_data[:start_vertex]))
    gasoline_end_node = GasolineEndUse_transform
    gasoline_edge = Edge(
        Symbol(id, "_", gasoline_edge_key),
        gasoline_edge_data,
        system.time_data[:Gasoline],
        Gasoline,
        gasoline_start_node,
        gasoline_end_node,
    )
    gasoline_edge.constraints = get(gasoline_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    gasoline_edge.unidirectional = true;
    gasoline_edge.has_capacity = false;

    gasoline_demand_edge_key = :gasoline_demand_edge
    gasoline_demand_edge_data = process_data(data[:edges][gasoline_demand_edge_key])
    gasoline_demand_start_node = GasolineEndUse_transform
    gasoline_demand_end_node = find_node(system.locations, Symbol(gasoline_demand_edge_data[:end_vertex]))
    gasoline_demand_edge = Edge(
        Symbol(id, "_", gasoline_demand_edge_key),
        gasoline_demand_edge_data,
        system.time_data[:Gasoline],
        Gasoline,
        gasoline_demand_start_node,
        gasoline_demand_end_node,
    )
    gasoline_demand_edge.constraints = Vector{AbstractTypeConstraint}()
    gasoline_demand_edge.unidirectional = true;
    gasoline_demand_edge.has_capacity = false;

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = GasolineEndUse_transform
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

    GasolineEndUse_transform.balance_data = Dict(
        :gasoline_demand => Dict(
            gasoline_edge.id => 1.0,
            gasoline_demand_edge.id => 1.0
        ),
        :emissions => Dict(
            gasoline_edge.id => get(transform_data, :emission_rate, 1.0),
            co2_edge.id => 1.0
        )
    )

    return GasolineEndUse(id, GasolineEndUse_transform, gasoline_edge, gasoline_demand_edge, co2_edge) 
end
