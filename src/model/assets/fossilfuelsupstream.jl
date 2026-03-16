struct FossilFuelsUpstream{T} <: AbstractAsset
    id::AssetId
    fossilfuelsupstream_transform::Transformation
    fossil_fuel_edge::Edge{<:T}
    fuel_edge::Edge{<:T}
    co2_edge::Edge{<:CO2}
end

FossilFuelsUpstream(
    id::AssetId,
    fossilfuelsupstream_transform::Transformation,
    fossil_fuel_edge::Edge{<:T},
    fuel_edge::Edge{<:T},
    co2_edge::Edge{<:CO2}
) where {T<:LiquidFuels} =
    FossilFuelsUpstream{LiquidFuels}(id, fossilfuelsupstream_transform, fossil_fuel_edge, fuel_edge, co2_edge)

    FossilFuelsUpstream(
    id::AssetId,
    fossilfuelsupstream_transform::Transformation,
    fossil_fuel_edge::Edge{<:T},
    fuel_edge::Edge{T},
    co2_edge::Edge{<:CO2}
) where {T<:Commodity} =
    FossilFuelsUpstream{T}(id, fossilfuelsupstream_transform, fossil_fuel_edge, fuel_edge, co2_edge)

function default_data(t::Type{FossilFuelsUpstream}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end
    
function full_default_data(::Type{FossilFuelsUpstream}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "LiquidFuels",
            :emission_rate => 0.0,
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :fossil_fuel_edge => @edge_data(
                :commodity => "LiquidFuels",
            ),
            :fuel_edge => @edge_data(
                :commodity => "LiquidFuels",
            ),
            :co2_edge => @edge_data(
                :commodity => "CO2",
                :co2_sink => missing,
            ),
        ),
    )
end

function simple_default_data(::Type{FossilFuelsUpstream}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :emission_rate => 0.0,
        :co2_sink => missing,
        :fuel_commodity => missing,
        :fossil_fuel_commodity => missing,
    )
end

function set_commodity!(::Type{FossilFuelsUpstream}, commodity::Type{<:Commodity}, data::AbstractDict{Symbol,Any})
    edge_keys = [:fossil_fuel_edge, :fuel_edge, :co2_edge]
    if haskey(data, :fuel_commodity)
        data[:fuel_commodity] = string(commodity)
    end
    if haskey(data, :fossil_fuel_commodity)
        data[:fossil_fuel_commodity] = string(commodity)
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

function make(asset_type::Type{FossilFuelsUpstream}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    fuelfossilupstream_key = :transforms
    @process_data(
        transform_data, 
        data[fuelfossilupstream_key], 
        [
            (data[fuelfossilupstream_key], key),
            (data[fuelfossilupstream_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    fossilfuelsupstream_transform = Transformation(;
        id = Symbol(id, "_", fuelfossilupstream_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        location = location,
        constraints = transform_data[:constraints],
    )

    fossil_fuel_edge_key = :fossil_fuel_edge
    @process_data(
        fossil_fuel_edge_data, 
        data[:edges][fossil_fuel_edge_key], 
        [
            (data[:edges][fossil_fuel_edge_key], key),
            (data[:edges][fossil_fuel_edge_key], Symbol("fossil_fuel_", key)),
            (data, Symbol("fossil_fuel_", key)),
        ]
    )
    commodity_symbol = Symbol(fossil_fuel_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    @start_vertex(
        fossil_fuel_start_node,
        fossil_fuel_edge_data,
        commodity,
        [(fossil_fuel_edge_data, :start_vertex), (data, :location)],
    )
    fossil_fuel_end_node = fossilfuelsupstream_transform
    fossil_fuel_edge = Edge(
        Symbol(id, "_", fossil_fuel_edge_key),
        fossil_fuel_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        fossil_fuel_start_node,
        fossil_fuel_end_node,
    )

    fuel_edge_key = :fuel_edge
    @process_data(
        fuel_edge_data, 
        data[:edges][fuel_edge_key], 
        [
            (data[:edges][fuel_edge_key], key),
            (data[:edges][fuel_edge_key], Symbol("fuel_", key)),
            (data, Symbol("fuel_", key)),
        ]
    )
    commodity_symbol = Symbol(fuel_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    fuel_start_node = fossilfuelsupstream_transform
    @end_vertex(
        fuel_end_node,
        fuel_edge_data,
        commodity,
        [(fuel_edge_data, :end_vertex), (data, :location)],
    )
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
        ]
    )
    co2_start_node = fossilfuelsupstream_transform
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

    fossilfuelsupstream_transform.balance_data = Dict(
        :fuel => Dict(
            fossil_fuel_edge.id => 1.0,
            fuel_edge.id => 1.0
        ),
        :emissions => Dict(
            fossil_fuel_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0
        )
    )

    return FossilFuelsUpstream(id, fossilfuelsupstream_transform, fossil_fuel_edge, fuel_edge, co2_edge) 
end
