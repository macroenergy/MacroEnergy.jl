struct Electrolyzer <: AbstractAsset
    id::AssetId
    electrolyzer_transform::Transformation
    h2_edge::Edge{Hydrogen}
    e_edge::Edge{Electricity}
end

"""
    make(::Type{Electrolyzer}, data::AbstractDict{Symbol, Any}, system::System) -> Electrolyzer

    Necessary data fields:
     - transforms: Dict{Symbol, Any}
        - id: String
        - timedata: String
        - efficiency_rate: Float64
        - constraints: Vector{AbstractTypeConstraint}
    - edges: Dict{Symbol, Any}
        - h2_edge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
        - e_edge: Dict{Symbol, Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(::Type{Electrolyzer}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    electrolyzer_key = :transforms 
    transform_data = process_data(data[electrolyzer_key])
    electrolyzer = Transformation(;
        id = Symbol(id, "_", electrolyzer_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    elec_edge_key = :e_edge
    elec_edge_data = process_data(data[:edges][elec_edge_key])
    elec_start_node = find_node(system.locations, Symbol(elec_edge_data[:start_vertex]))
    elec_end_node = electrolyzer
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    elec_edge.unidirectional = get(elec_edge_data, :unidirectional, true)

    h2_edge_key = :h2_edge
    h2_edge_data = process_data(data[:edges][h2_edge_key])
    h2_start_node = electrolyzer
    h2_end_node = find_node(system.locations, Symbol(h2_edge_data[:end_vertex]))
    h2_edge = Edge(
        Symbol(id, "_", h2_edge_key),
        h2_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_start_node,
        h2_end_node,
    )
    h2_edge.constraints = get(h2_edge_data, :constraints, [CapacityConstraint()])
    h2_edge.unidirectional = get(h2_edge_data, :unidirectional, true)

    electrolyzer.balance_data = Dict(
        :energy => Dict(
            h2_edge.id => 1.0,
            elec_edge.id => get(transform_data, :efficiency_rate, 1.0),
        ),
    )

    return Electrolyzer(id, electrolyzer, h2_edge, elec_edge)
end
