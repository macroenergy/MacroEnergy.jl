struct ThermalPowerCCS{T} <: AbstractAsset
    id::AssetId
    thermalpowerccs_transform::Transformation
    elec_edge::Union{Edge{Electricity},EdgeWithUC{Electricity}}
    fuel_edge::Edge{T}
    co2_edge::Edge{CO2}
    co2_captured_edge::Edge{CO2Captured}
end

ThermalPowerCCS(id::AssetId, thermal_transform::Transformation, elec_edge::Union{Edge{Electricity},EdgeWithUC{Electricity}}, fuel_edge::Edge{T}, co2_edge::Edge{CO2},co2_captured_edge::Edge{CO2Captured}) where T<:Commodity =
    ThermalPowerCCS{T}(id, thermal_transform, elec_edge, fuel_edge, co2_edge,co2_captured_edge)

function make(::Type{ThermalPowerCCS}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    thermalccs_key = :transforms
    transform_data = process_data(data[thermalccs_key])
    thermalccs_transform = Transformation(;
        id = Symbol(id, "_", thermalccs_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    elec_edge_key = :elec_edge
    elec_edge_data = process_data(data[:edges][elec_edge_key])
    elec_start_node = thermalccs_transform
    elec_end_node = find_node(system.locations, Symbol(elec_edge_data[:end_vertex]))
    if elec_edge_data[:uc]==true
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
        elec_edge.startup_fuel_balance_id = :energy
    else
        elec_edge = Edge(
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
                CapacityConstraint()
            ],
        )
    end
    elec_edge.unidirectional = true;
    

    fuel_edge_key = :fuel_edge
    fuel_edge_data = process_data(data[:edges][fuel_edge_key])
    T = commodity_types()[Symbol(fuel_edge_data[:type])];

    fuel_start_node = find_node(system.locations, Symbol(fuel_edge_data[:start_vertex]))
    fuel_end_node = thermalccs_transform
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
    co2_start_node = thermalccs_transform
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
    co2_captured_start_node = thermalccs_transform
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

    thermalccs_transform.balance_data = Dict(
        :energy => Dict(
            elec_edge.id => get(transform_data, :fuel_consumption, 1.0),
            fuel_edge.id => 1.0,
            co2_edge.id => 0.0,
            co2_captured_edge.id => 0.0,
        ),
        :emissions => Dict(
            fuel_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0,
            elec_edge.id => 0.0,
            co2_captured_edge.id => 0.0,
        ),
        :capture => Dict(
            fuel_edge.id => get(transform_data, :capture_rate, 0.0),
            co2_edge.id => 0.0,
            elec_edge.id => 0.0,
            co2_captured_edge.id => 1.0,
        ),
    )

    return ThermalPowerCCS(id, thermalccs_transform, elec_edge, fuel_edge, co2_edge, co2_captured_edge)
end
