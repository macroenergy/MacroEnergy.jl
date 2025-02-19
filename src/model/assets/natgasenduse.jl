struct NaturalGasEndUse <: AbstractAsset
    id::AssetId
    natgasenduse_transform::Transformation
    ng_edge::Edge{NaturalGas}
    ng_demand_edge::Edge{NaturalGas}
    co2_edge::Edge{CO2}
end

function make(::Type{NaturalGasEndUse}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    natgasdac_key = :transforms
    transform_data = process_data(data[natgasdac_key])
    natgasenduse_transform = Transformation(;
        id = Symbol(id, "_", natgasdac_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    ng_edge_key = :ng_edge
    ng_edge_data = process_data(data[:edges][ng_edge_key])
    ng_start_node = find_node(system.locations, Symbol(ng_edge_data[:start_vertex]))
    ng_end_node = natgasenduse_transform
    ng_edge = Edge(
        Symbol(id, "_", ng_edge_key),
        ng_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        ng_start_node,
        ng_end_node,
    )
    ng_edge.constraints = get(ng_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    ng_edge.unidirectional = true;
    ng_edge.has_capacity = false;

    ng_demand_edge_key = :ng_demand_edge
    ng_demand_edge_data = process_data(data[:edges][ng_demand_edge_key])
    ng_demand_start_node = natgasenduse_transform
    ng_demand_end_node = find_node(system.locations, Symbol(ng_demand_edge_data[:end_vertex]))
    ng_demand_edge = Edge(
        Symbol(id, "_", ng_demand_edge_key),
        ng_demand_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        ng_demand_start_node,
        ng_demand_end_node,
    )
    ng_demand_edge.constraints = Vector{AbstractTypeConstraint}()
    ng_demand_edge.unidirectional = true;
    ng_demand_edge.has_capacity = false;

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = natgasenduse_transform
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

    natgasenduse_transform.balance_data = Dict(
        :ng_demand => Dict(
            ng_edge.id => 1.0,
            ng_demand_edge.id => 1.0
        ),
        :emissions => Dict(
            ng_edge.id => get(transform_data, :emission_rate, 1.0),
            co2_edge.id => 1.0
        )
    )

    return NaturalGasEndUse(id, natgasenduse_transform, ng_edge, ng_demand_edge, co2_edge) 
end
