struct CementPlant{T} <: AbstractAsset
    id::AssetId
    cement_transform::Transformation
    elec_edge::Union{Edge{Electricity},EdgeWithUC{Electricity}}
    fuel_edge::Edge{T}
    cement_edge::Edge{Cement} # Cement produced
    co2_edge::Edge{CO2}
end

CementPlant(id::AssetId, cement_transform::Transformation, elec_edge::Union{Edge{Electricity},EdgeWithUC{Electricity}}, fuel_edge::Edge{T}, cement_edge::Edge{Cement}, co2_edge::Edge{CO2}) where T<:Commodity =
    CementPlant{T}(id, cement_transform, elec_edge, fuel_edge, cement_edge, co2_edge)

function default_data(::Type{CementPlant}, id=missing, style="full")
    return Dict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Cement",
            :fuel_cement_rate => 1.0,
            :elec_cement_rate => 1.0,
            :emission_rate => 0.0,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :elec_edge => @edge_data(
                :commodity => "Electricity"
            ),
            :fuel_edge => @edge_data(
                :commodity => missing
            ),
            :cement_edge => @edge_data(
                :commodity=>"Cement",
                :has_capacity => true,
                :can_retire => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true,
                )
            ),
            :co2_edge => @edge_data(
                :commodity=>"CO2",
                :co2_sink => missing,
            ),
        ),
    )
end

function make(asset_type::Type{CementPlant}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    @setup_data(asset_type, data, id)

    # Cement Transformation
    cement_key = :transforms
    @process_data(
        transform_data,
        data[cement_key],
        [
            (data[cement_key], key),
            (data[cement_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    cement_transform = Transformation(;
        id = Symbol(id, "_", cement_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    # Electricity Edge
    elec_edge_key = :elec_edge
    @process_data(
        elec_edge_data, 
        data[:edges][elec_edge_key], 
        [
            (data[:edges][elec_edge_key], key),
            (data[:edges][elec_edge_key], Symbol("elec_", key)),
            (data, Symbol("elec_", key)),
            (data, key),
        ]
    )

    @start_vertex(
        elec_start_node,
        elec_edge_data,
        Electricity,
        [(elec_edge_data, :start_vertex), (data, :location)],
    )
    elec_end_node = cement_transform

    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )

    # Fuel Edge
    fuel_edge_key = :fuel_edge
    @process_data(
        fuel_edge_data, 
        data[:edges][fuel_edge_key], 
        [
            (data[:edges][fuel_edge_key], key),
            (data[:edges][fuel_edge_key], Symbol("fuel_", key)),
            (data, Symbol("fuel_", key)),
            (data, key),
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
    fuel_end_node = cement_transform
    fuel_edge = Edge(
        Symbol(id, "_", fuel_edge_key),
        fuel_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        fuel_start_node,
        fuel_end_node,
    )

    # Cement Edge
    cement_edge_key = :cement_edge
    @process_data(
        cement_edge_data, 
        data[:edges][cement_edge_key], 
        [
            (data[:edges][cement_edge_key], key),
            (data[:edges][cement_edge_key], Symbol("cement_", key)),
            (data, Symbol("cement_", key)),
            (data, key),
        ]
    )
    cement_start_node = cement_transform
    @end_vertex(
        cement_end_node,
        cement_edge_data,
        Cement,
        [(cement_edge_data, :end_vertex), (data, :location)],
    )
    cement_edge = Edge(
        Symbol(id, "_", cement_edge_key),
        cement_edge_data,
        system.time_data[:Cement],
        Cement,
        cement_start_node,
        cement_end_node,
    )

    # CO2 Edge
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
    co2_start_node = cement_transform
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

    # Balance Constraint Values
    cement_transform.balance_data = Dict(
        :elec_to_cement => Dict(
            elec_edge.id => 1.0,
            fuel_edge.id => 0,
            cement_edge.id => get(transform_data, :elec_cement_rate, 1.0),
            co2_edge.id => 0
        ),
        :fuel_to_cement => Dict(
            elec_edge.id => 0,
            fuel_edge.id => 1.0,
            cement_edge.id => get(transform_data, :fuel_cement_rate, 1.0),
            co2_edge.id => 0,
        ),
        :emissions => Dict(
            elec_edge.id => 0,
            fuel_edge.id => 0,
            cement_edge.id => get(transform_data, :emission_rate, 1.0),
            co2_edge.id => -1.0,
        )
    )


    return CementPlant(id, cement_transform, elec_edge, fuel_edge, cement_edge, co2_edge)
end
