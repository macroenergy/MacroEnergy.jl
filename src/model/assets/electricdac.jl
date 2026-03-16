struct ElectricDAC <: AbstractAsset
    id::AssetId
    electricdac_transform::Transformation
    co2_edge::Edge{<:CO2}
    elec_edge::Edge{<:Electricity}
    co2_captured_edge::Edge{<:CO2Captured}
end

function default_data(t::Type{ElectricDAC}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{ElectricDAC}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Electricity",
            :electricity_consumption => 0.0,
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :co2_edge => @edge_data(
                :commodity => "CO2",
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                ),
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :co2_sink => missing,
            ),
            :elec_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :co2_captured_edge => @edge_data(
                :commodity => "CO2Captured",
            ),
        ),
    )
end

function simple_default_data(::Type{ElectricDAC}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :co2_sink => missing,
        :electricity_consumption => 0.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

function make(asset_type::Type{ElectricDAC}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    electricdac_key = :transforms
    @process_data(
        transform_data,
        data[electricdac_key],
        [
            (data[electricdac_key], key),
            (data[electricdac_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),            
        ]
    )
    electricdac_transform = Transformation(;
        id=Symbol(id, "_", electricdac_key),
        timedata=system.time_data[Symbol(transform_data[:timedata])],
        location = location,
        constraints=transform_data[:constraints],
    )

    co2_edge_key = :co2_edge
    @process_data(
        co2_edge_data, 
        data[:edges][co2_edge_key], 
        [
            (data[:edges][co2_edge_key], key),
            (data[:edges][co2_edge_key], Symbol("co2_", key)),
            (data, Symbol("co2_", key)),
            (data, key),
        ]
    )
    @start_vertex(
        co2_start_node,
        co2_edge_data,
        CO2,
        [(co2_edge_data, :start_vertex), (data, :co2_sink), (data, :location)],
    )
    co2_end_node = electricdac_transform
    co2_edge = Edge(
        Symbol(id, "_", co2_edge_key),
        co2_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_start_node,
        co2_end_node,
    )

    elec_edge_key = :elec_edge
    @process_data(
        elec_edge_data, 
        data[:edges][elec_edge_key], 
        [
            (data[:edges][elec_edge_key], key),
            (data[:edges][elec_edge_key], Symbol("elec_", key)),
            (data, Symbol("elec_", key)),
        ]
    )
    @start_vertex(
        elec_start_node,
        elec_edge_data,
        Electricity,
        [(elec_edge_data, :start_vertex), (data, :location)],
    )
    elec_end_node = electricdac_transform
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )

    co2_captured_edge_key = :co2_captured_edge
    @process_data(
        co2_captured_edge_data, 
        data[:edges][co2_captured_edge_key], 
        [
            (data[:edges][co2_captured_edge_key], key),
            (data[:edges][co2_captured_edge_key], Symbol("co2_captured_", key)),
            (data, Symbol("co2_captured_", key)),
        ]
    )
    co2_captured_start_node = electricdac_transform
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

    electricdac_transform.balance_data = Dict(
        :energy => Dict(
            co2_captured_edge.id => get(transform_data, :electricity_consumption, 0.0),
            elec_edge.id => 1.0,
        ),
        :capture => Dict(
            co2_edge.id => 1.0,
            co2_captured_edge.id => 1.0,
        ),
    )

    return ElectricDAC(id, electricdac_transform, co2_edge, elec_edge, co2_captured_edge)
end
