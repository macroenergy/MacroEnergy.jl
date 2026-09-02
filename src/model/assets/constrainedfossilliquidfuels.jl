struct ConstrainedFossilLiquidFuels <: AbstractAsset
    id::AssetId
    refinery_transform::Transformation
    fossil_gasoline_edge::Edge{<:LiquidFuels}
    fossil_jetfuel_edge::Edge{<:LiquidFuels}
    fossil_diesel_edge::Edge{<:LiquidFuels}
    gasoline_edge::Edge{<:LiquidFuels}
    jetfuel_edge::Edge{<:LiquidFuels}
    diesel_edge::Edge{<:LiquidFuels}
    co2_edge::Edge{<:CO2}
end

function default_data(t::Type{ConstrainedFossilLiquidFuels}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{ConstrainedFossilLiquidFuels}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "LiquidFuels",
            :jetfuel_ratio => 0.0,
            :diesel_ratio => 0.0,
            :gasoline_emission_rate => 0.0,
            :jetfuel_emission_rate => 0.0,
            :diesel_emission_rate => 0.0,
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :fossil_gasoline_edge => @edge_data(
                :commodity => "Gasoline",
                :unidirectional => true,
                :has_capacity => false,
            ),
            :fossil_jetfuel_edge => @edge_data(
                :commodity => "JetFuel",
                :unidirectional => true,
                :has_capacity => false,
            ),
            :fossil_diesel_edge => @edge_data(
                :commodity => "Diesel",
                :unidirectional => true,
                :has_capacity => false,
            ),
            :gasoline_edge => @edge_data(
                :commodity => "Gasoline",
                :unidirectional => true,
                :has_capacity => false,
            ),
            :jetfuel_edge => @edge_data(
                :commodity => "JetFuel",
                :unidirectional => true,
                :has_capacity => false,
            ),
            :diesel_edge => @edge_data(
                :commodity => "Diesel",
                :unidirectional => true,
                :has_capacity => false,
            ),
            :co2_edge => @edge_data(
                :commodity => "CO2",
                :co2_sink => missing,
                :unidirectional => true,
                :has_capacity => false,
            ),
        ),
    )
end

function simple_default_data(::Type{ConstrainedFossilLiquidFuels}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :jetfuel_ratio => 0.0,
        :diesel_ratio => 0.0,
        :gasoline_emission_rate => 0.0,
        :jetfuel_emission_rate => 0.0,
        :diesel_emission_rate => 0.0,
        :co2_sink => missing,
    )
end

function make(asset_type::Type{ConstrainedFossilLiquidFuels}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    @setup_data(asset_type, data, id)

    refinery_transform_key = :transforms
    @process_data(
        transform_data,
        data[refinery_transform_key],
        [
            (data[refinery_transform_key], key),
            (data[refinery_transform_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    refinery_transform = Transformation(;
        id = Symbol(id, "_", refinery_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = transform_data[:constraints],
    )

    fossil_gasoline_edge_key = :fossil_gasoline_edge
    @process_data(
        fossil_gasoline_edge_data,
        data[:edges][fossil_gasoline_edge_key],
        [
            (data[:edges][fossil_gasoline_edge_key], key),
            (data[:edges][fossil_gasoline_edge_key], Symbol("fossil_gasoline_", key)),
            (data, Symbol("fossil_gasoline_", key)),
        ]
    )
    commodity_symbol = Symbol(fossil_gasoline_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    @start_vertex(
        fossil_gasoline_start_node,
        fossil_gasoline_edge_data,
        commodity,
        [(fossil_gasoline_edge_data, :start_vertex), (data, :location)],
    )
    fossil_gasoline_edge = Edge(
        Symbol(id, "_", fossil_gasoline_edge_key),
        fossil_gasoline_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        fossil_gasoline_start_node,
        refinery_transform,
    )

    fossil_jetfuel_edge_key = :fossil_jetfuel_edge
    @process_data(
        fossil_jetfuel_edge_data,
        data[:edges][fossil_jetfuel_edge_key],
        [
            (data[:edges][fossil_jetfuel_edge_key], key),
            (data[:edges][fossil_jetfuel_edge_key], Symbol("fossil_jetfuel_", key)),
            (data, Symbol("fossil_jetfuel_", key)),
        ]
    )
    commodity_symbol = Symbol(fossil_jetfuel_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    @start_vertex(
        fossil_jetfuel_start_node,
        fossil_jetfuel_edge_data,
        commodity,
        [(fossil_jetfuel_edge_data, :start_vertex), (data, :location)],
    )
    fossil_jetfuel_edge = Edge(
        Symbol(id, "_", fossil_jetfuel_edge_key),
        fossil_jetfuel_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        fossil_jetfuel_start_node,
        refinery_transform,
    )

    fossil_diesel_edge_key = :fossil_diesel_edge
    @process_data(
        fossil_diesel_edge_data,
        data[:edges][fossil_diesel_edge_key],
        [
            (data[:edges][fossil_diesel_edge_key], key),
            (data[:edges][fossil_diesel_edge_key], Symbol("fossil_diesel_", key)),
            (data, Symbol("fossil_diesel_", key)),
        ]
    )
    commodity_symbol = Symbol(fossil_diesel_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    @start_vertex(
        fossil_diesel_start_node,
        fossil_diesel_edge_data,
        commodity,
        [(fossil_diesel_edge_data, :start_vertex), (data, :location)],
    )
    fossil_diesel_edge = Edge(
        Symbol(id, "_", fossil_diesel_edge_key),
        fossil_diesel_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        fossil_diesel_start_node,
        refinery_transform,
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
        refinery_transform,
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
        refinery_transform,
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
        refinery_transform,
        diesel_end_node,
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
        refinery_transform,
        co2_end_node,
    )

    jetfuel_ratio = get(transform_data, :jetfuel_ratio, 0.0)
    diesel_ratio  = get(transform_data, :diesel_ratio,  0.0)

    @add_balance(refinery_transform, :gasoline_balance, flow(fossil_gasoline_edge) == flow(gasoline_edge))
    @add_balance(refinery_transform, :jetfuel_balance, flow(fossil_jetfuel_edge) == flow(jetfuel_edge))
    @add_balance(refinery_transform, :diesel_balance, flow(fossil_diesel_edge) == flow(diesel_edge))
    # ratio constraints: jetfuel = jetfuel_ratio * gasoline, diesel = diesel_ratio * gasoline
    # sign trick: both edges are inputs, so each contributes -coeff*flow;
    # using coeff=-ratio for gasoline gives: -jetfuel + ratio*gasoline = 0
    @add_balance(refinery_transform, :jetfuel_ratio_constraint, flow(fossil_jetfuel_edge) == jetfuel_ratio * flow(fossil_gasoline_edge))
    @add_balance(refinery_transform, :diesel_ratio_constraint, flow(fossil_diesel_edge) == diesel_ratio * flow(fossil_gasoline_edge))
    @add_balance(
        refinery_transform,
        :emissions,
        get(transform_data, :gasoline_emission_rate, 0.0) * flow(fossil_gasoline_edge) +
        get(transform_data, :jetfuel_emission_rate, 0.0) * flow(fossil_jetfuel_edge) +
        get(transform_data, :diesel_emission_rate, 0.0) * flow(fossil_diesel_edge) == flow(co2_edge),
    )

    return ConstrainedFossilLiquidFuels(
        id,
        refinery_transform,
        fossil_gasoline_edge,
        fossil_jetfuel_edge,
        fossil_diesel_edge,
        gasoline_edge,
        jetfuel_edge,
        diesel_edge,
        co2_edge,
    )
end
