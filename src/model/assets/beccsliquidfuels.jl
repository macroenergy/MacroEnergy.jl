struct BECCSLiquidFuels <: AbstractAsset
    id::AssetId
    beccs_transform::Transformation
    biomass_edge::Edge{<:Biomass}
    gasoline_edge::Edge{<:LiquidFuels}
    jetfuel_edge::Edge{<:LiquidFuels}
    diesel_edge::Edge{<:LiquidFuels}
    elec_production_edge::Edge{<:Electricity}
    elec_consumption_edge::Edge{<:Electricity}
    co2_edge::Edge{<:CO2}
    co2_emission_edge::Edge{<:CO2}
    co2_captured_edge::Edge{<:CO2Captured}
end

function default_data(t::Type{BECCSLiquidFuels}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{BECCSLiquidFuels}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Biomass",
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true
            ),
            :gasoline_production => 0.0,
            :jetfuel_production => 0.0,
            :diesel_production => 0.0,
            :electricity_consumption => 0.0,
            :electricity_production => 0.0,
            :co2_content => 0.0,
            :emission_rate => 1.0,
            :capture_rate => 1.0
        ),
        :edges => Dict{Symbol,Any}(
            :biomass_edge => @edge_data(
                :commodity => "Biomass",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                )
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
            :co2_edge => @edge_data(
                :commodity => "CO2",
                :co2_sink => missing,
            ),
            :co2_emission_edge => @edge_data(
                :commodity => "CO2",
                :co2_sink => missing,
            ),
            :elec_consumption_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :elec_production_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :co2_captured_edge => @edge_data(
                :commodity => "CO2Captured",
            )
        )
    )
end

function simple_default_data(::Type{BECCSLiquidFuels}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :gaseline_commodity => "LiquidFuels",
        :jetfuel_commodity => "LiquidFuels",
        :diesel_commodity => "LiquidFuels",
        :co2_sink => missing,
        :gasoline_production => 0.0,
        :jetfuel_production => 0.0,
        :diesel_production => 0.0,
        :electricity_consumption => 0.0,
        :electricity_production => 0.0,
        :co2_content => 0.0,
        :emission_rate => 1.0,
        :capture_rate => 1.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

function make(asset_type::Type{BECCSLiquidFuels}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    beccs_transform_key = :transforms
    @process_data(
        transform_data,
        data[beccs_transform_key],
        [
            (data[beccs_transform_key], key),
            (data[beccs_transform_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    beccs_transform = Transformation(;
        id = Symbol(id, "_", beccs_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        location = location,
        constraints = transform_data[:constraints],
    )

    biomass_edge_key = :biomass_edge
    @process_data(
        biomass_edge_data,
        data[:edges][biomass_edge_key],
        [
            (data[:edges][biomass_edge_key], key),
            (data[:edges][biomass_edge_key], Symbol("biomass_", key)),
            (data, Symbol("biomass_", key)),
            (data, key),
        ]
    )
    commodity_symbol = Symbol(biomass_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    @start_vertex(
        biomass_start_node,
        biomass_edge_data,
        commodity,
        [(biomass_edge_data, :start_vertex), (data, :location)],
    )
    biomass_end_node = beccs_transform
    biomass_edge = Edge(
        Symbol(id, "_", biomass_edge_key),
        biomass_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        biomass_start_node,
        biomass_end_node,
    )

    gasoline_edge_key = :gasoline_edge
    @process_data(
        gasoline_edge_data,
        data[:edges][gasoline_edge_key],
        [
            (data[:edges][gasoline_edge_key], key), 
            (data[:edges][gasoline_edge_key], Symbol("gasoline_", key)),
            (data, Symbol("gasoline_", key)), 
        ],
    )
    commodity_symbol = Symbol(gasoline_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    gasoline_start_node = beccs_transform
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
    jetfuel_start_node = beccs_transform
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
    diesel_start_node = beccs_transform
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

    elec_consumption_edge_key = :elec_consumption_edge
    @process_data(
        elec_consumption_edge_data,
        data[:edges][elec_consumption_edge_key],
        [
            (data[:edges][elec_consumption_edge_key], key),
            (data[:edges][elec_consumption_edge_key], Symbol("elec_consumption_", key)),
            (data, Symbol("elec_consumption_", key)),
        ]
    )
    @start_vertex(
        elec_start_node,
        elec_consumption_edge_data,
        Electricity,
        [(elec_consumption_edge_data, :start_vertex), (data, :location)],
    )
    elec_end_node = beccs_transform
    elec_consumption_edge = Edge(
        Symbol(id, "_", elec_consumption_edge_key),
        elec_consumption_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )

    elec_production_edge_key = :elec_production_edge
    @process_data(
        elec_production_edge_data, 
        data[:edges][elec_production_edge_key],
        [
            (data[:edges][elec_production_edge_key], key),
            (data[:edges][elec_production_edge_key], Symbol("elec_production_", key)),
            (data, Symbol("elec_production_", key)),
        ]
    )
    elec_start_node = beccs_transform
    @end_vertex(
        elec_end_node,
        elec_production_edge_data,
        Electricity,
        [(elec_production_edge_data, :end_vertex), (data, :location)],
    )
    elec_production_edge = Edge(
        Symbol(id, "_", elec_production_edge_key),
        elec_production_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )

    co2_edge_key = :co2_edge
    @process_data(
        co2_edge_data,
        data[:edges][co2_edge_key],
        [
            (data[:edges][co2_edge_key], key),
            (data[:edges][co2_edge_key], Symbol("co2_", key)),
            (data, Symbol("co2_", key)),
        ]
    )
    @start_vertex(
        co2_start_node,
        co2_edge_data,
        CO2,
        [(co2_edge_data, :start_vertex), (data, :co2_sink), (data, :location)],
    )
    co2_end_node = beccs_transform
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
    co2_emission_start_node = beccs_transform
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
    co2_captured_start_node = beccs_transform
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

    beccs_transform.balance_data = Dict(
        :gasoline_production => Dict(
            gasoline_edge.id => 1.0,
            biomass_edge.id => get(transform_data, :gasoline_production, 0.0)
        ),
        :jetfuel_production => Dict(
            jetfuel_edge.id => 1.0,
            biomass_edge.id => get(transform_data, :jetfuel_production, 0.0)
        ),
        :diesel_production => Dict(
            diesel_edge.id => 1.0,
            biomass_edge.id => get(transform_data, :diesel_production, 0.0)
        ),
        :elec_production => Dict(
            elec_production_edge.id => 1.0,
            biomass_edge.id => get(transform_data, :electricity_production, 0.0)
        ),
        :elec_consumption => Dict(
            elec_consumption_edge.id => -1.0,
            biomass_edge.id => get(transform_data, :electricity_consumption, 0.0)
        ),
        :negative_emissions => Dict(
            biomass_edge.id => get(transform_data, :co2_content, 0.0),
            co2_edge.id => -1.0
        ),
        :emissions => Dict(
            biomass_edge.id => get(transform_data, :emission_rate, 1.0),
            co2_emission_edge.id => 1.0
        ),
        :capture =>Dict(
            biomass_edge.id => get(transform_data, :capture_rate, 1.0),
            co2_captured_edge.id => 1.0
        )
    )

    return BECCSLiquidFuels(id, beccs_transform, biomass_edge, gasoline_edge, jetfuel_edge, diesel_edge, elec_production_edge, elec_consumption_edge, co2_edge, co2_emission_edge, co2_captured_edge) 
end