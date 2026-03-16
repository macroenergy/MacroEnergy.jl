struct FuelsEndUse{T} <: AbstractAsset
    id::AssetId
    fuelsenduse_transform::Transformation
    fuel_edge::Edge{<:T}
    fuel_demand_edge::Edge{<:T}
    co2_edge::Edge{<:CO2}
end

FuelsEndUse(id::AssetId, fuelsenduse_transform::Transformation, fuel_edge::Edge{T}, fuel_demand_edge::Edge{T}, co2_edge::Edge{<:CO2}) where T<:Commodity =
    FuelsEndUse{T}(id, fuelsenduse_transform, fuel_edge, fuel_demand_edge, co2_edge)

function default_data(t::Type{FuelsEndUse}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{FuelsEndUse}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "LiquidFuels",
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
            :emission_rate => 0.0,
        ),
        :edges => Dict{Symbol, Any}(
            :fuel_edge => @edge_data(
                :commodity => "LiquidFuels",
            ),
            :fuel_demand_edge => @edge_data(
                :commodity => "LiquidFuels",
            ),
            :co2_edge => @edge_data(
                :commodity => "CO2",
                :co2_sink => missing,
            ),
        ),

    )
end

function simple_default_data(::Type{FuelsEndUse}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :co2_sink => missing,
        :emission_rate => 0.0,
        :fuel_commodity => "LiquidFuels",
        :fuel_demand_commodity => "LiquidFuels",
        :fuel_demand_end_vertex => missing,
        :timedata => "LiquidFuels",
    )
end

function set_commodity!(::Type{FuelsEndUse}, commodity::Type{<:Commodity}, data::AbstractDict{Symbol,Any})
    edge_keys = [:fuel_edge, :fuel_demand_edge,]
    if haskey(data, :fuel_commodity)
        data[:fuel_commodity] = string(commodity)
    end
    if haskey(data, :fuel_demand_commodity)
        data[:fuel_demand_commodity] = string(commodity)
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
    return nothing
end

function make(asset_type::Type{FuelsEndUse}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    FuelsEndUse_key = :transforms
    @process_data(
        transform_data, 
        data[FuelsEndUse_key], 
        [
            (data[FuelsEndUse_key], key),
            (data[FuelsEndUse_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    fuelsenduse_transform = Transformation(;
        id = Symbol(id, "_", FuelsEndUse_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        location = location,
        constraints = transform_data[:constraints],
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
    @start_vertex(
        fuel_start_node,
        fuel_edge_data,
        commodity,
        [(fuel_edge_data, :start_vertex), (data, :location)],
    )
    fuel_end_node = fuelsenduse_transform
    fuel_edge = Edge(
        Symbol(id, "_", fuel_edge_key),
        fuel_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        fuel_start_node,
        fuel_end_node,
    )

    fuel_demand_edge_key = :fuel_demand_edge
    @process_data(
        fuel_demand_edge_data, 
        data[:edges][fuel_demand_edge_key], 
        [
            (data[:edges][fuel_demand_edge_key], key),
            (data[:edges][fuel_demand_edge_key], Symbol("fuel_demand_", key)),
            (data, Symbol("fuel_demand_", key)),
        ]
    )
    fuel_demand_start_node = fuelsenduse_transform
    @end_vertex(
        fuel_demand_end_node,
        fuel_demand_edge_data,
        commodity,
        [(fuel_demand_edge_data, :end_vertex), (data, :location)],
    )
    fuel_demand_edge = Edge(
        Symbol(id, "_", fuel_demand_edge_key),
        fuel_demand_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        fuel_demand_start_node,
        fuel_demand_end_node,
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
    co2_start_node = fuelsenduse_transform
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

    fuelsenduse_transform.balance_data = Dict(
        :fuel_demand => Dict(
            fuel_edge.id => 1.0,
            fuel_demand_edge.id => 1.0
        ),
        :emissions => Dict(
            fuel_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0
        )
    )

    return FuelsEndUse(id, fuelsenduse_transform, fuel_edge, fuel_demand_edge, co2_edge) 
end
