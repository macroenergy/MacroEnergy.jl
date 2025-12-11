struct ThermalSteam{T} <: AbstractAsset
    id::AssetId
    steam_transform::Transformation
    steam_edge::Union{Edge{<:Steam},EdgeWithUC{<:Steam}}
    fuel_edge::Edge{<:T}
    elec_edge::Edge{<:Electricity}
    co2_edge::Edge{<:CO2}
end

ThermalSteam(id::AssetId, steam_transform::Transformation, steam_edge::Union{Edge{<:Steam},EdgeWithUC{<:Steam}}, fuel_edge::Edge{T}, elec_edge::Edge{<:Electricity}, co2_edge::Edge{<:CO2}) where T<:Commodity =
    ThermalSteam{T}(id, steam_transform, steam_edge, fuel_edge, elec_edge, co2_edge)

function default_data(t::Type{ThermalSteam}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{ThermalSteam}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Steam",
            :fuel_consumption => 1.0,
            :startup_fuel_consumption => 0.0,
            :emission_rate => 0.0,
            :elec_cogen_rate => 0.0,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :steam_edge => @edge_data(
                :commodity => "Steam",
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
            :elec_edge => @edge_data(
                :commodity=>"Electricity",
                :has_capacity => false,
            ),
            :co2_edge => @edge_data(
                :commodity=>"CO2",
                :co2_sink => missing,
            ),
        ),
    )
end

function simple_default_data(::Type{ThermalSteam}, id=missing)
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
        :elec_cogen_rate => 1.0,
        :startup_cost => 0.0,
        :startup_fuel_consumption => 0.0,
        :min_up_time => 0,
        :min_down_time => 0,
        :ramp_up_fraction => 0.0,
        :ramp_down_fraction => 0.0,
    )
end

function set_commodity!(::Type{ThermalSteam}, commodity::Type{<:Commodity}, data::AbstractDict{Symbol,Any})
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
    make(::Type{ThermalSteam}, data::AbstractDict{Symbol, Any}, system::System) -> ThermalSteam
"""

function make(asset_type::Type{ThermalSteam}, data::AbstractDict{Symbol,Any}, system::System)
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
    steam_transform = Transformation(;
        id = Symbol(id, "_", thermal_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    steam_edge_key = :steam_edge
    @process_data(
        steam_edge_data, 
        data[:edges][steam_edge_key], 
        [
            (data[:edges][steam_edge_key], key),
            (data[:edges][steam_edge_key], Symbol("steam_", key)),
            (data, Symbol("steam_", key)),
            (data, key),
        ]
    )
    steam_start_node = steam_transform
    @end_vertex(
        steam_end_node,
        steam_edge_data,
        Steam,
        [(steam_edge_data, :end_vertex), (data, :location)],
    )
    # Check if the edge has unit commitment constraints
    has_uc = get(steam_edge_data, :uc, false)
    EdgeType = has_uc ? EdgeWithUC : Edge
    # Create the steam edge with the appropriate type
    steam_edge = EdgeType(
        Symbol(id, "_", steam_edge_key),
        steam_edge_data,
        system.time_data[:Steam],
        Steam,
        steam_start_node,
        steam_end_node,
    )
    if has_uc
        uc_constraints = [MinUpTimeConstraint(), MinDownTimeConstraint()]
        for c in uc_constraints
            if !(c in steam_edge.constraints)
                push!(steam_edge.constraints, c)
            end
        end
        steam_edge.startup_fuel_balance_id = :energy
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
    fuel_end_node = steam_transform
    fuel_edge = Edge(
        Symbol(id, "_", fuel_edge_key),
        fuel_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        fuel_start_node,
        fuel_end_node,
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
    elec_start_node = steam_transform
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
    co2_start_node = steam_transform
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

    steam_transform.balance_data = Dict(
        :energy => Dict(
            steam_edge.id => get(transform_data, :fuel_consumption, 1.0),
            fuel_edge.id => 1.0,
            elec_edge.id => 0.0,
            co2_edge.id => 0.0,
        ),
        :elec_prod => Dict(
            fuel_edge.id => get(transform_data, :elec_cogen_rate, 1.0),
            elec_edge.id => 1.0,
            co2_edge.id => 0.0,
            steam_edge.id => 0.0,
        ),
        :emissions => Dict(
            fuel_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0,
            steam_edge.id => 0.0,
        ),
    )


    return ThermalSteam(id, steam_transform, steam_edge, fuel_edge, elec_edge, co2_edge)
end
