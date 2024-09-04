struct DirectAirCaptureNG <: AbstractAsset
    natgasdac_capture_transform::Transformation
    e_edge::Edge{Electricity}
    ng_edge::Edge{NaturalGas}
    co2_edge::Edge{CO2}
    captured_co2_edge::Edge{Captured_CO2}
end

id(ng_dac::DirectAirCaptureNG) = ng_dac.natgasdac_capture_transform.id

function add_capacity_factor!(ng_dac::DirectAirCaptureNG, capacity_factor::Vector{Float64})
    ng_dac.co2_edge.capacity_factor = capacity_factor
end

"""
    make(::Type{DirectAirCaptureNG}, data::AbstractDict{Symbol, Any}, system::System) -> DirectAirCaptureNG

    Necessary data fields:
     - transforms: Dict{Symbol, Any}
        - id: String
        - time_commodity: String
        - heat_rate: Float64
        - elec_out: Float64
        - capture_rate: Float64
        - constraints: Vector{AbstractTypeConstraint}
    - edges: Dict{Symbol, Any}
        - elec: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
        - natgas: Dict{Symbol, Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
        - co2: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
        - captured co2: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(::Type{DirectAirCaptureNG}, data::AbstractDict{Symbol, Any}, system::System)

    transform_data = validate_data(data[:transforms])
    natgasdac_transform = Transformation(;
        id = Symbol(transform_data[:id]),
        timedata = system.time_data[Symbol(transform_data[:time_commodity])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()])
    )

    co2_edge_data = validate_data(data[:edges][:co2])
    co2_start_node = find_node(system.locations, Symbol(co2_edge_data[:start_vertex]))
    co2_end_node = natgasdac_transform
    co2_edge = Edge(Symbol(co2_edge_data[:id]),co2_edge_data, system.time_data[:CO2],CO2, co2_start_node,  co2_end_node);
    co2_edge.constraints = get(co2_edge_data, :constraints,  [CapacityConstraint()])
    co2_edge.unidirectional = get(co2_edge_data, :unidirectional, true);

    ng_edge_data = validate_data(data[:edges][:natgas])
    ng_start_node = find_node(system.locations, Symbol(ng_edge_data[:start_vertex]))
    ng_end_node = natgasdac_transform
    ng_edge = Edge(Symbol(ng_edge_data[:id]),ng_edge_data, system.time_data[:NaturalGas],NaturalGas, ng_start_node,  ng_end_node);
    ng_edge.constraints = get(ng_edge_data, :constraints,  Vector{AbstractTypeConstraint}())
    ng_edge.unidirectional = get(ng_edge_data, :unidirectional, true);

    elec_edge_data = validate_data(data[:edges][:elec])
    elec_start_node = natgasdac_transform
    elec_end_node = find_node(system.locations, Symbol(elec_edge_data[:end_vertex]))
    elec_edge = Edge(Symbol(elec_edge_data[:id]),elec_edge_data, system.time_data[:Electricity],Electricity, elec_start_node,  elec_end_node);
    elec_edge.constraints = get(elec_edge_data, :constraints,  Vector{AbstractTypeConstraint}())
    elec_edge.unidirectional = get(elec_edge_data, :unidirectional, true);

    captured_co2_edge_data = validate_data(data[:edges][:captured_co2])
    captured_co2_start_node = natgasdac_transform
    captured_co2_end_node = find_node(system.locations, Symbol(captured_co2_edge_data[:end_vertex]))
    captured_co2_edge = Edge(Symbol(captured_co2_edge_data[:id]),captured_co2_edge_data, system.time_data[:Captured_CO2],Captured_CO2, captured_co2_start_node,  captured_co2_end_node);
    captured_co2_edge.constraints = get(captured_co2_edge_data, :constraints,  Vector{AbstractTypeConstraint}())
    captured_co2_edge.unidirectional = get(captured_co2_edge_data, :unidirectional, true);

    natgasdac_transform.balance_data =  Dict(:energy_ng=>Dict(co2_edge.id=>get(transform_data,:heat_rate,1.0),
                                                        ng_edge.id=>-1.0,
                                                        elec_edge.id=>0.0,
                                                        captured_co2_edge.id=>0.0),
                                          :energy_elec=>Dict(co2_edge.id=>get(transform_data,:elec_out,0.0),
                                                            ng_edge.id=>0.0,
                                                            captured_co2_edge.id=>0.0,
                                                            elec_edge.id=>1.0),
                                            :captured=>Dict(co2_edge.id=>get(transform_data,:capture_rate,1.0),
                                                            ng_edge.id=>0.0,
                                                            captured_co2_edge.id=>1.0,
                                                            elec_edge.id=>0.0))


    return DirectAirCaptureNG(natgasdac_transform, elec_edge, ng_edge, co2_edge, captured_co2_edge)
end