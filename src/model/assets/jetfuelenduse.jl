struct JetFuelEndUse <: AbstractAsset
    id::AssetId
    JetFuelEndUse_transform::Transformation
    jetfuel_edge::Edge{JetFuel}
    jetfuel_demand_edge::Edge{JetFuel}
    co2_edge::Edge{CO2}
end

function make(::Type{JetFuelEndUse}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    JetFuelEndUse_key = :transforms
    transform_data = process_data(data[JetFuelEndUse_key])
    JetFuelEndUse_transform = Transformation(;
        id = Symbol(id, "_", JetFuelEndUse_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    jetfuel_edge_key = :jetfuel_edge
    jetfuel_edge_data = process_data(data[:edges][jetfuel_edge_key])
    jetfuel_start_node = find_node(system.locations, Symbol(jetfuel_edge_data[:start_vertex]))
    jetfuel_end_node = JetFuelEndUse_transform
    jetfuel_edge = Edge(
        Symbol(id, "_", jetfuel_edge_key),
        jetfuel_edge_data,
        system.time_data[:JetFuel],
        JetFuel,
        jetfuel_start_node,
        jetfuel_end_node,
    )
    jetfuel_edge.constraints = get(jetfuel_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    jetfuel_edge.unidirectional = true;
    jetfuel_edge.has_capacity = false;

    jetfuel_demand_edge_key = :jetfuel_demand_edge
    jetfuel_demand_edge_data = process_data(data[:edges][jetfuel_demand_edge_key])
    jetfuel_demand_start_node = JetFuelEndUse_transform
    jetfuel_demand_end_node = find_node(system.locations, Symbol(jetfuel_demand_edge_data[:end_vertex]))
    jetfuel_demand_edge = Edge(
        Symbol(id, "_", jetfuel_demand_edge_key),
        jetfuel_demand_edge_data,
        system.time_data[:JetFuel],
        JetFuel,
        jetfuel_demand_start_node,
        jetfuel_demand_end_node,
    )
    jetfuel_demand_edge.constraints = Vector{AbstractTypeConstraint}()
    jetfuel_demand_edge.unidirectional = true;
    jetfuel_demand_edge.has_capacity = false;

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = JetFuelEndUse_transform
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

    JetFuelEndUse_transform.balance_data = Dict(
        :jetfuel_demand => Dict(
            jetfuel_edge.id => 1.0,
            jetfuel_demand_edge.id => 1.0
        ),
        :emissions => Dict(
            jetfuel_edge.id => get(transform_data, :emission_rate, 1.0),
            co2_edge.id => 1.0
        )
    )

    return JetFuelEndUse(id, JetFuelEndUse_transform, jetfuel_edge, jetfuel_demand_edge, co2_edge) 
end
