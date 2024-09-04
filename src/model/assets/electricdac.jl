struct DirectAirCaptureElectric <: AbstractAsset
    electricdac_capture_transform::Transformation
    e_edge::Edge{Electricity}
    co2_edge::Edge{CO2}
    captured_co2_edge::Edge{Captured_CO2}
end

id(electric_dac::DirectAirCaptureElectric) = electric_dac.electricdac_capture_transform.id

function add_capacity_factor!(electric_dac::DirectAirCaptureElectric, capacity_factor::Vector{Float64})
    electric_dac.co2_edge.capacity_factor = capacity_factor
end

"""
    make(::Type{DirectAirCaptureElectric}, data::AbstractDict{Symbol, Any}, system::System) -> DirectAirCaptureElectric

    Necessary data fields:
     - transforms: Dict{Symbol, Any}
        - id: String
        - time_commodity: String
        - heat_rate: Float64
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
function make(::Type{DirectAirCaptureElectric}, data::AbstractDict{Symbol, Any}, system::System)

    transform_data = validate_data(data[:transforms])
    electricdac_transform = Transformation(;
        id = Symbol(transform_data[:id]),
        timedata = system.time_data[Symbol(transform_data[:time_commodity])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()])
    )

    co2_edge_data = validate_data(data[:edges][:co2])
    co2_start_node = find_node(system.locations, Symbol(co2_edge_data[:start_vertex]))
    co2_end_node = electricdac_transform
    co2_edge = Edge(Symbol(co2_edge_data[:id]),co2_edge_data, system.time_data[:CO2],CO2, co2_start_node,  co2_end_node);
    co2_edge.constraints = get(co2_edge_data, :constraints,  [CapacityConstraint()])
    co2_edge.unidirectional = get(co2_edge_data, :unidirectional, true);

    elec_edge_data = validate_data(data[:edges][:elec])
    elec_start_node = find_node(system.locations, Symbol(elec_edge_data[:start_vertex]))
    elec_end_node = electricdac_transform
    elec_edge = Edge(Symbol(elec_edge_data[:id]),elec_edge_data, system.time_data[:Electricity],Electricity, elec_start_node,  elec_end_node);
    elec_edge.constraints = get(elec_edge_data, :constraints,  Vector{AbstractTypeConstraint}())
    elec_edge.unidirectional = get(elec_edge_data, :unidirectional, true);

    captured_co2_edge_data = validate_data(data[:edges][:captured_co2])
    captured_co2_start_node = electricdac_transform
    captured_co2_end_node = find_node(system.locations, Symbol(captured_co2_edge_data[:end_vertex]))
    captured_co2_edge = Edge(Symbol(captured_co2_edge_data[:id]),captured_co2_edge_data, system.time_data[:Captured_CO2],Captured_CO2, captured_co2_start_node,  captured_co2_end_node);
    captured_co2_edge.constraints = get(captured_co2_edge_data, :constraints,  Vector{AbstractTypeConstraint}())
    captured_co2_edge.unidirectional = get(captured_co2_edge_data, :unidirectional, true);

    electricdac_transform.balance_data =  Dict(:energy=>Dict(co2_edge.id=>get(transform_data,:elec_in,1.0),
                                                        elec_edge.id=>-1.0,
                                                        captured_co2_edge.id=>0.0),
                                            :captured=>Dict(co2_edge.id=>get(transform_data,:capture_rate,1.0),
                                                            captured_co2_edge.id=>1.0,
                                                            elec_edge.id=>0.0))


    return DirectAirCaptureElectric(electricdac_transform, elec_edge, co2_edge, captured_co2_edge)
end