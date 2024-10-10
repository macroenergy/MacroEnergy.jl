struct ThermalPower{T} <: AbstractAsset
    id::AssetId
    thermal_transform::Transformation
    elec_edge::Union{Edge{Electricity},EdgeWithUC{Electricity}}
    fuel_edge::Edge{T}
    co2_edge::Edge{CO2}
end

ThermalPower(id::AssetId, thermal_transform::Transformation, elec_edge::Union{Edge{Electricity},EdgeWithUC{Electricity}}, fuel_edge::Edge{T}, co2_edge::Edge{CO2}) where T<:Commodity =
    ThermalPower{T}(id, thermal_transform, elec_edge, fuel_edge, co2_edge)

function make(::Type{ThermalPower}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    thermal_key = :transforms
    transform_data = process_data(data[thermal_key])
    thermal_transform = Transformation(;
        id = Symbol(id, "_", thermal_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    elec_edge_key = :elec_edge
    elec_edge_data = process_data(data[:edges][elec_edge_key])
    elec_start_node = thermal_transform
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
    elec_edge.unidirectional = true;
    elec_edge.startup_fuel_balance_id = :energy

    fuel_edge_key = :fuel_edge
    fuel_edge_data = process_data(data[:edges][fuel_edge_key])
    T = commodity_types()[Symbol(fuel_edge_data[:type])];

    fuel_start_node = find_node(system.locations, Symbol(fuel_edge_data[:start_vertex]))
    fuel_end_node = thermal_transform
    fuel_edge = Edge(
        Symbol(id, "_", fuel_edge_key),
        fuel_edge_data,
        system.time_data[Symbol(T)],
        T,
        fuel_start_node,
        fuel_end_node,
    )
    fuel_edge.constraints = Vector{AbstractTypeConstraint}();
    fuel_edge.unidirectional = true;
    fuel_edge.has_capacity = false;

    co2_edge_key = :co2_edge
    co2_edge_data = process_data(data[:edges][co2_edge_key])
    co2_start_node = thermal_transform
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

    thermal_transform.balance_data = Dict(
        :energy => Dict(
            elec_edge.id => 1.0,
            fuel_edge.id => get(transform_data, :efficiency_rate, 1.0),
            co2_edge.id => 0.0,
        ),
        :emissions => Dict(
            fuel_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0,
            elec_edge.id => 0.0,
        ),
    )


    return ThermalPower(id, thermal_transform, elec_edge, fuel_edge, co2_edge)
end
