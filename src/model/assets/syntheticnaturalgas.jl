struct SyntheticNaturalGas <: AbstractAsset
    id::AssetId
    synthetic_natural_gas_transform::Transformation
    co2_captured_edge::Edge{<:CO2Captured}
    natgas_edge::Edge{<:NaturalGas}
    elec_edge::Edge{<:Electricity}
    h2_edge::Edge{<:Hydrogen}
    co2_emission_edge::Edge{<:CO2}
end

function default_data(t::Type{SyntheticNaturalGas}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{SyntheticNaturalGas}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "CO2Captured",
            :natgas_production => 0.0,
            :electricity_consumption => 0.0,
            :h2_consumption => 0.0,
            :emission_rate => 1.0,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :co2_captured_edge => @edge_data(
                :commodity => "CO2Captured",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true
                ),
            ),
            :natgas_edge => @edge_data(
                :commodity => "NaturalGas",
            ),
            :elec_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :h2_edge => @edge_data(
                :commodity => "Hydrogen",
            ),
            :co2_emission_edge => @edge_data(
                :commodity => "CO2",
                :co2_sink => missing,
            ),
        ),
    )
end

function simple_default_data(::Type{SyntheticNaturalGas}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :co2_sink => missing,
        :natgas_production => 0.0,
        :electricity_consumption => 0.0,
        :h2_consumption => 0.0,
        :emission_rate => 1.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

"""
    make(::Type{SyntheticNaturalGas}, data::AbstractDict{Symbol, Any}, system::System) -> SyntheticNaturalGas
"""

function make(asset_type::Type{SyntheticNaturalGas}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    @setup_data(asset_type, data, id)

    synthetic_natural_gas_transform_key = :transforms
    @process_data(
        transform_data, 
        data[synthetic_natural_gas_transform_key], 
        [
            (data[synthetic_natural_gas_transform_key], key),
            (data[synthetic_natural_gas_transform_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    synthetic_natural_gas_transform = Transformation(;
        id = Symbol(id, "_", synthetic_natural_gas_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    co2_captured_edge_key = :co2_captured_edge
    @process_data(
        co2_captured_edge_data, 
        data[:edges][co2_captured_edge_key], 
        [
            (data[:edges][co2_captured_edge_key], key),
            (data[:edges][co2_captured_edge_key], Symbol("co2_captured_", key)),
            (data, Symbol("co2_captured_", key)),
            (data, key),
        ]
    )
    @start_vertex(
        co2_captured_start_node,
        co2_captured_edge_data,
        CO2Captured,
        [(co2_captured_edge_data, :start_vertex), (data, :location)],
    )
    co2_captured_end_node = synthetic_natural_gas_transform
    co2_captured_edge = Edge(
        Symbol(id, "_", co2_captured_edge_key),
        co2_captured_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_captured_start_node,
        co2_captured_end_node,
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
    natgas_start_node = synthetic_natural_gas_transform
    @end_vertex(
        natgas_end_node,
        natgas_edge_data,
        NaturalGas,
        [(natgas_edge_data, :end_vertex), (data, :location)],
    )
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
    @start_vertex(
        elec_start_node,
        elec_edge_data,
        Electricity,
        [(elec_edge_data, :start_vertex), (data, :location)],
    )
    elec_end_node = synthetic_natural_gas_transform
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )

    h2_edge_key = :h2_edge
    @process_data(
        h2_edge_data, 
        data[:edges][h2_edge_key], 
        [
            (data[:edges][h2_edge_key], key),
            (data[:edges][h2_edge_key], Symbol("h2_", key)),
            (data, Symbol("h2_", key)),
        ]
    )
    @start_vertex(
        h2_start_node,
        h2_edge_data,
        Hydrogen,
        [(h2_edge_data, :start_vertex), (data, :location)],
    )
    h2_end_node = synthetic_natural_gas_transform
    h2_edge = Edge(
        Symbol(id, "_", h2_edge_key),
        h2_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_start_node,
        h2_end_node,
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
    co2_emission_start_node = synthetic_natural_gas_transform
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

    synthetic_natural_gas_transform.balance_data = Dict(
        :natgas_production => Dict(
            natgas_edge.id => 1.0,
            co2_captured_edge.id => get(transform_data, :natgas_production, 0.0)
        ),
        :elec_consumption => Dict(
            elec_edge.id => -1.0,
            co2_captured_edge.id => get(transform_data, :electricity_consumption, 0.0)
        ),
        :h2_consumption => Dict(
            h2_edge.id => -1.0,
            co2_captured_edge.id => get(transform_data, :h2_consumption, 0.0)
        ),
        :emissions => Dict(
            co2_captured_edge.id => get(transform_data, :emission_rate, 1.0),
            co2_emission_edge.id => 1.0
        )
    )

    return SyntheticNaturalGas(id, synthetic_natural_gas_transform, co2_captured_edge,natgas_edge,elec_edge,h2_edge,co2_emission_edge) 
end
