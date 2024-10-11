struct ThermalHydrogenCCS{T} <: AbstractAsset
    id::AssetId
    thermalhydrogenccs_transform::Transformation
    h2_edge::Union{Edge{Hydrogen},EdgeWithUC{Hydrogen}}
    elec_edge::Edge{Electricity}
    fuel_edge::Edge{T}
    co2_edge::Edge{CO2}
    co2_captured_edge::Edge{CO2Captured}
end
ThermalHydrogenCCS(id::AssetId, thermalhydrogenccs_transform::Transformation,h2_edge::Union{Edge{Hydrogen},EdgeWithUC{Hydrogen}}, elec_edge::Edge{Electricity},
fuel_edge::Edge{T},co2_edge::Edge{CO2},co2_captured_edge::Edge{CO2Captured})where T<:Commodity =
    ThermalHydrogenCCS{T}(id, thermalhydrogenccs_transform, h2_edge, elec_edge, fuel_edge, co2_edge,co2_captured_edge)

"""
    make(::Type{ThermalHydrogenCCS}, data::AbstractDict{Symbol, Any}, system::System) -> ThermalHydrogenCCS

    Necessary data fields:
     - transforms: Dict{Symbol, Any}
        - id: String
        - timedata: String
        - efficiency_rate: Float64
        - emission_rate: Float64
        - constraints: Vector{AbstractTypeConstraint}
    - edges: Dict{Symbol, Any}
        - elec_edge: Dict{Symbol,Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_capacity: Bool
        - h2_edge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_capacity: Bool
            - can_retire: Bool
            - can_expand: Bool
            - min_up_time: Int
            - min_down_time: Int
            - startup_cost: Float64
            - startup_fuel: Float64
            - startup_fuel_balance_id: Symbol
            - constraints: Vector{AbstractTypeConstraint}
        - fuel_edge: Dict{Symbol, Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_capacity: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
        - co2_edge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_capacity: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
        - co2_captured_edge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_capacity: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(::Type{ThermalHydrogenCCS}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    thermalhydrogenccs_key = :transforms
    transform_data = process_data(data[thermalhydrogenccs_key])
    thermalhydrogenccs_transform = Transformation(;
        id = Symbol(id, "_", thermalhydrogenccs_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    elec_edge_key = :elec_edge
    elec_edge_data = process_data(data[:edges][elec_edge_key]);
    elec_start_node = find_node(system.locations, Symbol(elec_edge_data[:start_vertex]))
    elec_end_node = thermalhydrogenccs_transform
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    elec_edge.has_capacity = false;
    elec_edge.unidirectional = true;
    elec_edge.constraints =  Vector{AbstractTypeConstraint}();

    h2_edge_key = :h2_edge
    h2_edge_data = process_data(data[:edges][h2_edge_key])
    h2_start_node = thermalhydrogenccs_transform
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
    h2_edge.unidirectional = true;
    h2_edge.startup_fuel_balance_id = :energy

    fuel_edge_key = :fuel_edge
    fuel_edge_data = process_data(data[:edges][fuel_edge_key])
    T = commodity_types()[Symbol(fuel_edge_data[:type])];
    fuel_start_node = find_node(system.locations, Symbol(fuel_edge_data[:start_vertex]))
    fuel_end_node = thermalhydrogenccs_transform
    fuel_edge = Edge(
        Symbol(id, "_", fuel_edge_key),
        fuel_edge_data,
        system.time_data[Symbol(T)],
        T,
        fuel_start_node,
        fuel_end_node,
    )
    fuel_edge.unidirectional = true;

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = thermalhydrogenccs_transform
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

    co2_captured_edge_key = :co2_captured_edge
    co2_captured_edge_data = process_data(data[:edges][co2_captured_edge_key])
    co2_captured_start_node = thermalhydrogenccs_transform
    co2_captured_end_node = find_node(system.locations, Symbol(co2_captured_edge_data[:end_vertex]))
    co2_captured_edge = Edge(
        Symbol(id, "_", co2_captured_edge_key),
        co2_captured_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_captured_start_node,
        co2_captured_end_node,
    )
    co2_captured_edge.constraints = Vector{AbstractTypeConstraint}()
    co2_captured_edge.unidirectional = true;
    co2_captured_edge.has_capacity = false;

    thermalhydrogenccs_transform.balance_data = Dict(
        :energy => Dict(
            h2_edge.id => 1.0,
            fuel_edge.id => get(transform_data, :efficiency_rate, 1.0),
        ),
        :electricity => Dict(
            h2_edge.id => get(transform_data, :electricity_consumption, 0.0),
            elec_edge.id => 1.0
        ),
        :emissions => Dict(
            fuel_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0,
        ),
        :capture => Dict(
            fuel_edge.id => get(transform_data, :capture_rate, 0.0),
            co2_captured_edge.id => 1.0,
        ),
    )


    return ThermalHydrogenCCS(id, thermalhydrogenccs_transform, h2_edge, elec_edge,fuel_edge, co2_edge, co2_captured_edge)
end
