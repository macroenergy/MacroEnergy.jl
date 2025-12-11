struct ThermalHeating{T} <: AbstractAsset
    id::AssetId
    heating_transform::Transformation
    heat_edge::Union{Edge{<:Heat},EdgeWithUC{<:Heat}}
    fuel_edge::Edge{<:T}
    co2_edge::Edge{<:CO2}
end

ThermalHeating(id::AssetId, heating_transform::Transformation, heat_edge::Union{Edge{<:Heat},EdgeWithUC{<:Heat}}, fuel_edge::Edge{T}, co2_edge::Edge{<:CO2}) where T<:Commodity =
    ThermalHeating{T}(id, heating_transform, heat_edge, fuel_edge, co2_edge)

function default_data(t::Type{ThermalHeating}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{ThermalHeating}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Heat",
            :fuel_consumption => 1.0,
            :startup_fuel_consumption => 0.0,
            :emission_rate => 0.0,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :heat_edge => @edge_data(
                :commodity => "Heat",
                :has_capacity => true,
                :can_retire => true,
                :can_expand => true,
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
        ),
    )
end

function simple_default_data(::Type{ThermalHeating}, id=missing)
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
        :emission_rate => 1.0,
        :startup_cost => 0.0,
        :startup_fuel_consumption => 0.0,
        :min_up_time => 0,
        :min_down_time => 0,
        :ramp_up_fraction => 0.0,
        :ramp_down_fraction => 0.0,
    )
end

function set_commodity!(::Type{ThermalHeating}, commodity::Type{<:Commodity}, data::AbstractDict{Symbol,Any})
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
    make(::Type{ThermalHeating}, data::AbstractDict{Symbol, Any}, system::System) -> ThermalHeating
"""

function make(asset_type::Type{ThermalHeating}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    @setup_data(asset_type, data, id)

    thermal_key = :transforms
    @process_data(
        transform_data, 
        data[thermal_key], 
        [
            (data[thermal_key], key),
            (data[thermal_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    heating_transform = Transformation(;
        id = Symbol(id, "_", thermal_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    heat_edge_key = :heat_edge
    @process_data(
        heat_edge_data, 
        data[:edges][heat_edge_key], 
        [
            (data[:edges][heat_edge_key], key),
            (data[:edges][heat_edge_key], Symbol("heat_", key)),
            (data, Symbol("heat_", key)),
            (data, key),
        ]
    )
    heat_start_node = heating_transform
    @end_vertex(
        heat_end_node,
        heat_edge_data,
        Heat,
        [(heat_edge_data, :end_vertex), (data, :location)],
    )
    # Check if the edge has unit commitment constraints
    has_uc = get(heat_edge_data, :uc, false)
    EdgeType = has_uc ? EdgeWithUC : Edge
    # Create the heat edge with the appropriate type
    heat_edge = EdgeType(
        Symbol(id, "_", heat_edge_key),
        heat_edge_data,
        system.time_data[:Heat],
        Heat,
        heat_start_node,
        heat_end_node,
    )
    if has_uc
        uc_constraints = [MinUpTimeConstraint(), MinDownTimeConstraint()]
        for c in uc_constraints
            if !(c in heat_edge.constraints)
                push!(heat_edge.constraints, c)
            end
        end
        heat_edge.startup_fuel_balance_id = :energy
    end
    
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
    fuel_end_node = heating_transform
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
    co2_start_node = heating_transform
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

    heating_transform.balance_data = Dict(
        :energy => Dict(
            heat_edge.id => get(transform_data, :fuel_consumption, 1.0),
            fuel_edge.id => 1.0,
            co2_edge.id => 0.0,
        ),
        :emissions => Dict(
            fuel_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0,
            heat_edge.id => 0.0,
        ),
    )


    return ThermalHeating(id, heating_transform, heat_edge, fuel_edge, co2_edge)
end
