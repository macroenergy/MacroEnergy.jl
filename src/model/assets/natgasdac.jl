struct NaturalGasDAC <: AbstractAsset
    id::AssetId
    natgaspowerdac_transform::Transformation
    co2_edge::Edge{CO2}
    ng_edge::Edge{NaturalGas}
    e_edge::Edge{Electricity}
    co2_captured_edge::Edge{CO2Captured}
end

"""
    make(::Type{NaturalGasDAC}, data::AbstractDict{Symbol, Any}, system::System) -> NaturalGasDAC

    Necessary data fields:
     - transforms: Dict{Symbol, Any}
        - id: String
        - timedata: String
        - heat_rate: Float64
        - emission_rate: Float64
        - constraints: Vector{AbstractTypeConstraint}
    - edges: Dict{Symbol, Any}
        - co2_edge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
        - ng_edge: Dict{Symbol, Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
        - e_edge: Dict{Symbol, Any}
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
function make(::Type{NaturalGasDAC}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    natgasdac_key = :transforms
    transform_data = process_data(data[natgasdac_key])
    natgasdac_transform = Transformation(;
        id = Symbol(id, "_", natgasdac_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = find_node(system.locations, Symbol(co2_edge_data[:start_vertex]))
    co2_end_node = natgasdac_transform
    co2_edge = Edge(
        Symbol(id, "_", co2_edge_key),
        co2_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_start_node,
        co2_end_node,
    )
    co2_edge.constraints = get(co2_edge_data, :constraints, [CapacityConstraint()])
    co2_edge.unidirectional = get(co2_edge_data, :unidirectional, true)

    ng_edge_key = :ng_edge
    ng_edge_data = process_data(data[:edges][ng_edge_key])
    ng_start_node = find_node(system.locations, Symbol(ng_edge_data[:start_vertex]))
    ng_end_node = natgasdac_transform
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

    elec_edge_key = :e_edge
    elec_edge_data = process_data(data[:edges][elec_edge_key])
    elec_start_node = natgasdac_transform
    elec_end_node = find_node(system.locations, Symbol(elec_edge_data[:end_vertex]))
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    elec_edge.constraints = get(elec_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    elec_edge.unidirectional = get(elec_edge_data, :unidirectional, true)
    
    co2_captured_edge_key = :co2_captured_edge
    co2_captured_edge_data = process_data(data[:edges][co2_captured_edge_key])
    co2_captured_start_node = natgasdac_transform
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

    natgasdac_transform.balance_data = Dict(
        :energy => Dict(
            co2_edge.id => get(transform_data, :heat_rate, 1.0),
            ng_edge.id => -1.0,
            elec_edge.id => 0.0,
            co2_captured_edge.id => 0.0,
        ),
        :elec_credit => Dict(
            co2_edge.id => get(transform_data, :elec_out, 0.0),
            ng_edge.id => 0.0,
            elec_edge.id => 1.0,
            co2_captured_edge.id => 0.0,
        ),
        :capture => Dict(
            co2_edge.id => get(transform_data, :capture_rate, 1.0),
            ng_edge.id => 0.0,
            elec_edge.id => 0.0,
            co2_captured_edge.id => 1.0,
        ),
    )

    return NaturalGasDAC(id, natgasdac_transform, co2_edge, ng_edge, elec_edge, co2_captured_edge)
end
