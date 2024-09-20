struct NaturalGasHydrogen <: AbstractAsset
    id::AssetId
    natgashydrogen_transform::Transformation
    h2_edge::Union{Edge{Hydrogen},EdgeWithUC{Hydrogen}}
    ng_edge::Edge{NaturalGas}
    co2_edge::Edge{CO2}
end

"""
    make(::Type{NaturalGasHydrogen}, data::AbstractDict{Symbol, Any}, system::System) -> NaturalGasHydrogen

    Necessary data fields:
     - transforms: Dict{Symbol, Any}
        - id: String
        - timedata: String
        - efficiency_rate: Float64
        - emission_rate: Float64
        - constraints: Vector{AbstractTypeConstraint}
    - edges: Dict{Symbol, Any}
        - h2_edge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - min_up_time: Int
            - min_down_time: Int
            - startup_cost: Float64
            - startup_fuel: Float64
            - startup_fuel_balance_id: Symbol
            - constraints: Vector{AbstractTypeConstraint}
        - ng_edge: Dict{Symbol, Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
        - co2_edge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(::Type{NaturalGasHydrogen}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    natgashydrogen_key = :transforms
    transform_data = process_data(data[natgashydrogen_key])
    natgashydrogen_transform = Transformation(;
        id = Symbol(id, "_", natgashydrogen_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    h2_edge_key = :h2_edge
    h2_edge_data = process_data(data[:edges][h2_edge_key])
    h2_start_node = natgashydrogen_transform
    h2_end_node = find_node(system.locations, Symbol(h2_edge_data[:end_vertex]))
    h2_edge = EdgeWithUC(
        Symbol(id, "_", h2_edge_key),
        h2_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_start_node,
        h2_end_node,
    )
    h2_edge.constraints = get(
        h2_edge_data,
        :constraints,
        [
            CapacityConstraint(),
            RampingLimitConstraint(),
            MinUpTimeConstraint(),
            MinDownTimeConstraint(),
        ],
    )
    h2_edge.unidirectional = get(h2_edge_data, :unidirectional, true)
    h2_edge.startup_fuel_balance_id = :energy

    ng_edge_key = :ng_edge
    ng_edge_data = process_data(data[:edges][ng_edge_key])
    ng_start_node = find_node(system.locations, Symbol(ng_edge_data[:start_vertex]))
    ng_end_node = natgashydrogen_transform
    ng_edge = Edge(
        Symbol(id, "_", ng_edge_key),
        ng_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        ng_start_node,
        ng_end_node,
    )
    ng_edge.constraints = get(ng_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    ng_edge.unidirectional = get(ng_edge_data, :unidirectional, true)

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = natgashydrogen_transform
    co2_end_node = find_node(system.locations, Symbol(co2_edge_data[:end_vertex]))
    co2_edge = Edge(
        Symbol(id, "_", co2_edge_key),
        co2_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_start_node,
        co2_end_node,
    )
    co2_edge.constraints =
        get(co2_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    co2_edge.unidirectional = get(co2_edge_data, :unidirectional, true)

    natgashydrogen_transform.balance_data = Dict(
        :energy => Dict(
            h2_edge.id => 1.0,
            ng_edge.id => get(transform_data, :efficiency_rate, 1.0),
            co2_edge.id => 0.0,
        ),
        :emissions => Dict(
            ng_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0,
            h2_edge.id => 0.0,
        ),
    )


    return NaturalGasHydrogen(id, natgashydrogen_transform, h2_edge, ng_edge, co2_edge)
end
