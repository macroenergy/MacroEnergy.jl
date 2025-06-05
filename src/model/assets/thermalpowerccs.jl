struct ThermalPowerCCS{T} <: AbstractAsset
    id::AssetId
    thermalpowerccs_transform::Transformation
    elec_edge::Union{Edge{<:Electricity},EdgeWithUC{<:Electricity}}
    fuel_edge::Edge{<:T}
    co2_edge::Edge{<:CO2}
    co2_captured_edge::Edge{<:CO2Captured}
end

ThermalPowerCCS(id::AssetId, thermal_transform::Transformation, elec_edge::Union{Edge{<:Electricity},EdgeWithUC{<:Electricity}}, fuel_edge::Edge{T}, co2_edge::Edge{<:CO2},co2_captured_edge::Edge{<:CO2Captured}) where T<:Commodity =
    ThermalPowerCCS{T}(id, thermal_transform, elec_edge, fuel_edge, co2_edge,co2_captured_edge)

function default_data(t::Type{ThermalPowerCCS}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{ThermalPowerCCS}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Electricity",
            :fuel_consumption => 1.0,
            :startup_fuel_consumption => 0.0,
            :emission_rate => 0.0,
            :capture_rate => 1.0,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :elec_edge => @edge_data(
                :commodity => "Electricity",
                :has_capacity => true,
                :can_retire => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true,
                    :RampingLimitConstraint => true
                ),
            ),
            :fuel_edge => @edge_data(
                :commodity => missing,
            ),
            :co2_edge => @edge_data(
                :commodity=>"CO2",
                :co2_sink => missing,
            ),
            :co2_captured_edge => @edge_data(
                :commodity=>"CO2Captured",
            ),
        ),
    )
end

function simple_default_data(::Type{ThermalPowerCCS}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :capacity_size => 1.0,
        :timedata => "NaturalGas",
        :fuel_commodity => "NaturalGas",
        :co2_sink => missing,
        :uc => false,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
        :fuel_consumption => 0.0,
        :electricity_consumption => 0.0,
        :emission_rate => 1.0,
        :capture_rate => 1.0,
        :startup_cost => 0.0,
        :startup_fuel_consumption => 0.0,
        :min_up_time => 0,
        :min_down_time => 0,
        :ramp_up_fraction => 0.0,
        :ramp_down_fraction => 0.0,
    )
end

function set_commodity!(::Type{ThermalPowerCCS}, commodity::Type{<:Commodity}, data::AbstractDict{Symbol,Any})
    edge_keys = [:fuel_edge]
    if haskey(data, :fuel_commodity)
        data[:fuel_commodity] = string(commodity)
    end
    if haskey(data, :edges)
        for edge_key in edge_keys
            if haskey(data[:edges], edge_key)
                if haskey(data[:edges][edge_key], :commodity)
                    data[:edges][edge_key][:commodity] = string(commodity)
                end
            end
        end
    end
end

"""
    make(::Type{ThermalPowerCCS}, data::AbstractDict{Symbol, Any}, system::System) -> ThermalPowerCCS
"""

function make(asset_type::Type{ThermalPowerCCS}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    @setup_data(asset_type, data, id)

    thermalccs_key = :transforms
    @process_data(
        transform_data,
        data[thermalccs_key],
        [
            (data[thermalccs_key], key),
            (data[thermalccs_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ],
    )
    thermalccs_transform = Transformation(;
        id = Symbol(id, "_", thermalccs_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    elec_edge_key = :elec_edge
    @process_data(
        elec_edge_data, 
        data[:edges][elec_edge_key], 
        [
            (data[:edges][elec_edge_key], key),
            (data[:edges][elec_edge_key], Symbol("elec_", key)),
            (data, Symbol("elec_", key)),
            (data, key),
        ],
    )
    elec_start_node = thermalccs_transform
    @end_vertex(
        elec_end_node,
        elec_edge_data,
        Electricity,
        [(elec_edge_data, :end_vertex), (data, :location)],
    )
    # Check if the edge has unit commitment constraints
    has_uc = get(elec_edge_data, :uc, false)
    EdgeType = has_uc ? EdgeWithUC : Edge
    # Create the elec edge with the appropriate type
    elec_edge = EdgeType(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    if has_uc
        uc_constraints = [MinUpTimeConstraint(), MinDownTimeConstraint()]
        for c in uc_constraints
            if !(c in elec_edge.constraints)
                push!(elec_edge.constraints, c)
            end
        end
        elec_edge.startup_fuel_balance_id = :energy
    end

    fuel_edge_key = :fuel_edge
    @process_data(
        fuel_edge_data, 
        data[:edges][fuel_edge_key], 
        [
            (data[:edges][fuel_edge_key], key),
            (data[:edges][fuel_edge_key], Symbol("fuel_", key)),
            (data, Symbol("fuel_", key)),
        ],
    )
    commodity_symbol = Symbol(fuel_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    @start_vertex(
        fuel_start_node,
        fuel_edge_data,
        commodity,
        [(fuel_edge_data, :start_vertex), (data, :location)],
    )
    fuel_end_node = thermalccs_transform
    fuel_edge = Edge(
        Symbol(id, "_", fuel_edge_key),
        fuel_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        fuel_start_node,
        fuel_end_node,
    )

    co2_edge_key = :co2_edge
    @process_data(
        co2_edge_data, 
        data[:edges][co2_edge_key], 
        [
            (data[:edges][co2_edge_key], key),
            (data[:edges][co2_edge_key], Symbol("co2_", key)),
            (data, Symbol("co2_", key)),
        ],
    )
    co2_start_node = thermalccs_transform
    @end_vertex(
        co2_end_node,
        co2_edge_data,
        CO2,
        [(co2_edge_data, :end_vertex), (data, :co2_sink), (data, :location)],
    )
    co2_edge = Edge(
        Symbol(id, "_", co2_edge_key),
        co2_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_start_node,
        co2_end_node,
    )
    
    co2_captured_edge_key = :co2_captured_edge
    @process_data(
        co2_captured_edge_data, 
        data[:edges][co2_captured_edge_key], 
        [
            (data[:edges][co2_captured_edge_key], key),
            (data[:edges][co2_captured_edge_key], Symbol("co2_captured_", key)),
            (data, Symbol("co2_captured_", key)),
        ],
    )
    co2_captured_start_node = thermalccs_transform
    @end_vertex(
        co2_captured_end_node,
        co2_captured_edge_data,
        CO2Captured,
        [(co2_captured_edge_data, :end_vertex), (data, :location)],
    )
    co2_captured_edge = Edge(
        Symbol(id, "_", co2_captured_edge_key),
        co2_captured_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_captured_start_node,
        co2_captured_end_node,
    )

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
