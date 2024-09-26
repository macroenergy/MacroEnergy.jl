struct NaturalGasPowerCCS <: AbstractAsset
    id::AssetId
    natgaspowerccs_transform::Transformation
    e_edge::Union{Edge{Electricity},EdgeWithUC{Electricity}}
    ng_edge::Edge{NaturalGas}
    co2_edge::Edge{CO2}
    co2_captured_edge::Edge{CO2Captured}
end

"""
    make(::Type{NaturalGasPowerCCS}, data::AbstractDict{Symbol, Any}, system::System) -> NaturalGasPowerCCS

    Necessary data fields:
     - transforms: Dict{Symbol, Any}
        - id: String
        - timedata: String
        - heat_rate: Float64
        - emission_rate: Float64
        - constraints: Vector{AbstractTypeConstraint}
    - edges: Dict{Symbol, Any}
        - e_edge: Dict{Symbol, Any}
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
        - co2_captured_edge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(::Type{NaturalGasPowerCCS}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    natgasccs_key = :transforms
    transform_data = process_data(data[natgasccs_key])
    natgasccs_transform = Transformation(;
        id = Symbol(id, "_", natgasccs_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    elec_edge_key = :e_edge
    elec_edge_data = process_data(data[:edges][elec_edge_key])
    elec_start_node = natgasccs_transform
    elec_end_node = find_node(system.locations, Symbol(elec_edge_data[:end_vertex]))
    elec_edge = EdgeWithUC(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    elec_edge.constraints = get(
        elec_edge_data,
        :constraints,
        [
            CapacityConstraint(),
            RampingLimitConstraint(),
            MinUpTimeConstraint(),
            MinDownTimeConstraint(),
        ],
    )
    elec_edge.unidirectional = get(elec_edge_data, :unidirectional, true)
    elec_edge.startup_fuel_balance_id = :energy

    ng_edge_key = :ng_edge
    ng_edge_data = process_data(data[:edges][ng_edge_key])
    ng_start_node = find_node(system.locations, Symbol(ng_edge_data[:start_vertex]))
    ng_end_node = natgasccs_transform
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
    co2_start_node = natgasccs_transform
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
    
    co2_captured_edge_key = :co2_captured_edge
    co2_captured_edge_data = process_data(data[:edges][co2_captured_edge_key])
    co2_captured_start_node = natgasccs_transform
    co2_captured_end_node = find_node(system.locations, Symbol(co2_captured_edge_data[:end_vertex]))
    co2_captured_edge = Edge(
        Symbol(id, "_", co2_captured_edge_key),
        co2_captured_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_captured_start_node,
        co2_captured_end_node,
    )
    co2_captured_edge.constraints =
        get(co2_captured_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    co2_captured_edge.unidirectional = get(co2_captured_edge_data, :unidirectional, true)

    natgasccs_transform.balance_data = Dict(
        :energy => Dict(
            elec_edge.id => get(transform_data, :heat_rate, 1.0),
            ng_edge.id => 1.0,
            co2_edge.id => 0.0,
            co2_captured_edge.id => 0.0,
        ),
        :emissions => Dict(
            ng_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0,
            elec_edge.id => 0.0,
            co2_captured_edge.id => 0.0,
        ),
        :capture => Dict(
            ng_edge.id => get(transform_data, :capture_rate, 0.0),
            co2_edge.id => 0.0,
            elec_edge.id => 0.0,
            co2_captured_edge.id => 1.0,
        ),
    )

    return NaturalGasPowerCCS(id, natgasccs_transform, elec_edge, ng_edge, co2_edge, co2_captured_edge)
end
