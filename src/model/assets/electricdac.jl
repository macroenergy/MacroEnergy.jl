struct ElectricDAC <: AbstractAsset
    id::AssetId
    electricpowerdac_transform::Transformation
    co2_edge::Edge{CO2}
    e_edge::Edge{Electricity}
    co2_captured_edge::Edge{CO2Captured}
end

"""
    make(::Type{ElectricDAC}, data::AbstractDict{Symbol, Any}, system::System) -> ElectricDAC

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
function make(::Type{ElectricDAC}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    electricdac_key = :transforms
    transform_data = process_data(data[electricdac_key])
    electricdac_transform = Transformation(;
        id = Symbol(id, "_", electricdac_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = find_node(system.locations, Symbol(co2_edge_data[:start_vertex]))
    co2_end_node = electricdac_transform
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

    elec_edge_key = :e_edge
    elec_edge_data = process_data(data[:edges][elec_edge_key])
    elec_start_node = find_node(system.locations, Symbol(elec_edge_data[:start_vertex]))
    elec_end_node = electricdac_transform
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
    co2_captured_start_node = electricdac_transform
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

    electricdac_transform.balance_data = Dict(
        :energy => Dict(
            co2_edge.id => get(transform_data, :elec_in, 1.0),
            elec_edge.id => -1.0,
            co2_captured_edge.id => 0.0,
        ),
        :capture => Dict(
            co2_edge.id => get(transform_data, :capture_rate, 1.0),
            elec_edge.id => 0.0,
            co2_captured_edge.id => 1.0,
        ),
    )

    return ElectricDAC(id, electricdac_transform, co2_edge, elec_edge, co2_captured_edge)
end
