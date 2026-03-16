struct NaturalGasDAC <: AbstractAsset
    id::AssetId
    natgasdac_transform::Transformation
    co2_edge::Edge{<:CO2}
    co2_emission_edge::Edge{<:CO2}
    natgas_edge::Edge{<:NaturalGas}
    elec_edge::Edge{<:Electricity}
    co2_captured_edge::Edge{<:CO2Captured}
end

function default_data(t::Type{NaturalGasDAC}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{NaturalGasDAC}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "NaturalGas",
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
            :electricity_production => 0.0,
            :fuel_consumption => 0.0,
            :emission_rate => 1.0,
            :capture_rate => 1.0,
        ),
        :edges => Dict{Symbol,Any}(
            :co2_edge => @edge_data(
                :commodity => "CO2",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true
                ),
                :co2_sink => missing,
            ),
            :co2_emission_edge => @edge_data(
                :commodity => "CO2",
                :co2_sink => missing,
            ),
            :natgas_edge => @edge_data(
                :commodity => "NaturalGas",
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

function simple_default_data(::Type{NaturalGasDAC}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :co2_sink => missing,
        :emission_rate => 1.0,
        :capture_rate => 1.0,
        :fuel_consumption => 0.0,
        :electricity_production => 0.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

function make(asset_type::Type{NaturalGasDAC}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    natgasdac_key = :transforms
    @process_data(
        transform_data, 
        data[natgasdac_key], 
        [
            (data[natgasdac_key], key),
            (data[natgasdac_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    natgasdac_transform = Transformation(;
        id = Symbol(id, "_", natgasdac_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        location = location,
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
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
    co2_end_node = natgasdac_transform
    co2_edge = Edge(
        Symbol(id, "_", co2_edge_key),
        co2_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_start_node,
        co2_end_node,
    )

    co2_emission_edge_key = :co2_emission_edge
    @process_data(
        co2_emission_edge_data,
        data[:edges][co2_emission_edge_key],
        [
            (data[:edges][co2_emission_edge_key], key),
            (data[:edges][co2_emission_edge_key], Symbol("co2_emission_", key)),
            (data, Symbol("co2_emission_", key)),
        ]
    )
    co2_emission_start_node = natgasdac_transform
    @end_vertex(
        co2_emission_end_node,
        co2_emission_edge_data,
        CO2,
        [(co2_emission_edge_data, :end_vertex), (data, :co2_sink), (data, :location)],
    )
    co2_emission_edge = Edge(
        Symbol(id, "_", co2_emission_edge_key),
        co2_emission_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_emission_start_node,
        co2_emission_end_node,
    )

    natgas_edge_key = :natgas_edge
    @process_data(
        natgas_edge_data, 
        data[:edges][natgas_edge_key], 
        [
            (data[:edges][natgas_edge_key], key),
            (data[:edges][natgas_edge_key], Symbol("natgas_", key)),
            (data, Symbol("natgas_", key)),
        ]
    )
    @start_vertex(
        natgas_start_node,
        natgas_edge_data,
        NaturalGas,
        [(natgas_edge_data, :start_vertex), (data, :location)],
    )
    natgas_end_node = natgasdac_transform
    natgas_edge = Edge(
        Symbol(id, "_", natgas_edge_key),
        natgas_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        natgas_start_node,
        natgas_end_node,
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
    elec_start_node = natgasdac_transform
    @end_vertex(
        elec_end_node,
        elec_edge_data,
        Electricity,
        [(elec_edge_data, :end_vertex), (data, :location)],
    )
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
    co2_captured_start_node = natgasdac_transform
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

    natgasdac_transform.balance_data = Dict(
        :elec_production => Dict(
            elec_edge.id => 1.0,
            co2_edge.id => get(transform_data, :electricity_production, 0.0)
        ),
        :fuel_consumption => Dict(
            natgas_edge.id => -1.0,
            co2_edge.id => get(transform_data, :fuel_consumption, 0.0)
        ),
        :emissions => Dict(
            natgas_edge.id => get(transform_data, :emission_rate, 1.0),
            co2_emission_edge.id => 1.0
        ),
        :capture =>Dict(
            natgas_edge.id => get(transform_data, :capture_rate, 1.0),
            co2_edge.id => 1.0,
            co2_captured_edge.id => 1.0
        )
    )

    return NaturalGasDAC(id, natgasdac_transform, co2_edge,co2_emission_edge, natgas_edge, elec_edge, co2_captured_edge) 
end
