struct SyntheticLiquidFuels <: AbstractAsset
    id::AssetId
    synthetic_liquid_fuels_transform::Transformation
    co2_captured_edge::Edge{<:CO2Captured}
    gasoline_edge::Edge{<:LiquidFuels}
    jetfuel_edge::Edge{<:LiquidFuels}
    diesel_edge::Edge{<:LiquidFuels}
    elec_edge::Edge{<:Electricity}
    h2_edge::Edge{<:Hydrogen}
    co2_emission_edge::Edge{<:CO2}
end

function default_data(t::Type{SyntheticLiquidFuels}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{SyntheticLiquidFuels}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "CO2Captured",
            :gasoline_production => 0.0,
            :jetfuel_production => 0.0,
            :diesel_production => 0.0,
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
            :gasoline_edge => @edge_data(
                :commodity => "LiquidFuels",
            ),
            :jetfuel_edge => @edge_data(
                :commodity => "LiquidFuels",
            ),
            :diesel_edge => @edge_data(
                :commodity => "LiquidFuels",
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

function simple_default_data(::Type{SyntheticLiquidFuels}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :co2_sink => missing,
        :gasoline_commodity => "LiquidFuels",
        :jetfuel_commodity => "LiquidFuels",
        :diesel_commodity => "LiquidFuels",
        :gasoline_production => 0.0,
        :jetfuel_production => 0.0,
        :diesel_production => 0.0,
        :electricity_consumption => 0.0,
        :h2_consumption => 0.0,
        :emission_rate => 1.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

"""
    make(::Type{SyntheticLiquidFuels}, data::AbstractDict{Symbol, Any}, system::System) -> SyntheticLiquidFuels
"""

function make(asset_type::Type{SyntheticLiquidFuels}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    synthetic_liquid_fuels_transform_key = :transforms
    @process_data(
        transform_data,
        data[synthetic_liquid_fuels_transform_key],
        [
            (data[synthetic_liquid_fuels_transform_key], key),
            (data[synthetic_liquid_fuels_transform_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    synthetic_liquid_fuels_transform = Transformation(;
        id = Symbol(id, "_", synthetic_liquid_fuels_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        location = location,
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
    co2_captured_end_node = synthetic_liquid_fuels_transform
    co2_captured_edge = Edge(
        Symbol(id, "_", co2_captured_edge_key),
        co2_captured_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_captured_start_node,
        co2_captured_end_node,
    )

    gasoline_edge_key = :gasoline_edge
    @process_data(
        gasoline_edge_data,
        data[:edges][gasoline_edge_key],
        [
            (data[:edges][gasoline_edge_key], key),
            (data[:edges][gasoline_edge_key], Symbol("gasoline_", key)),
            (data, Symbol("gasoline_", key)),
        ]
    )
    commodity_symbol = Symbol(gasoline_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    gasoline_start_node = synthetic_liquid_fuels_transform
    @end_vertex(
        gasoline_end_node,
        gasoline_edge_data,
        commodity,
        [(gasoline_edge_data, :end_vertex), (data, :location)],
    )
    gasoline_edge = Edge(
        Symbol(id, "_", gasoline_edge_key),
        gasoline_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        gasoline_start_node,
        gasoline_end_node,
    )

    jetfuel_edge_key = :jetfuel_edge
    @process_data(
        jetfuel_edge_data,
        data[:edges][jetfuel_edge_key],
        [
            (data[:edges][jetfuel_edge_key], key),
            (data[:edges][jetfuel_edge_key], Symbol("jetfuel_", key)),
            (data, Symbol("jetfuel_", key)),
        ]
    )
    commodity_symbol = Symbol(jetfuel_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    jetfuel_start_node = synthetic_liquid_fuels_transform
    @end_vertex(
        jetfuel_end_node,
        jetfuel_edge_data,
        commodity,
        [(jetfuel_edge_data, :end_vertex), (data, :location)],
    )
    jetfuel_edge = Edge(
        Symbol(id, "_", jetfuel_edge_key),
        jetfuel_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        jetfuel_start_node,
        jetfuel_end_node,
    )

    diesel_edge_key = :diesel_edge
    @process_data(
        diesel_edge_data,
        data[:edges][diesel_edge_key],
        [
            (data[:edges][diesel_edge_key], key),
            (data[:edges][diesel_edge_key], Symbol("diesel_", key)),
            (data, Symbol("diesel_", key)),
        ]
    )
    commodity_symbol = Symbol(diesel_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    diesel_start_node = synthetic_liquid_fuels_transform
    @end_vertex(
        diesel_end_node,
        diesel_edge_data,
        commodity,
        [(diesel_edge_data, :end_vertex), (data, :location)],
    )
    diesel_edge = Edge(
        Symbol(id, "_", diesel_edge_key),
        diesel_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        diesel_start_node,
        diesel_end_node,
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
    elec_end_node = synthetic_liquid_fuels_transform
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
    h2_end_node = synthetic_liquid_fuels_transform
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
    co2_emission_start_node = synthetic_liquid_fuels_transform
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

    synthetic_liquid_fuels_transform.balance_data = Dict(
        :gasoline_production => Dict(
            gasoline_edge.id => 1.0,
            co2_captured_edge.id => get(transform_data, :gasoline_production, 0.0)
        ),
        :jetfuel_production => Dict(
            jetfuel_edge.id => 1.0,
            co2_captured_edge.id => get(transform_data, :jetfuel_production, 0.0)
        ),
        :diesel_production => Dict(
            diesel_edge.id => 1.0,
            co2_captured_edge.id => get(transform_data, :diesel_production, 0.0)
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

    return SyntheticLiquidFuels(id, synthetic_liquid_fuels_transform, co2_captured_edge,gasoline_edge,jetfuel_edge,diesel_edge,elec_edge,h2_edge,co2_emission_edge) 
end
