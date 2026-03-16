struct ElectricSteam <: AbstractAsset
    id::AssetId
    steam_transform::Transformation
    steam_edge::Edge{<:Steam}
    elec_edge::Edge{<:Electricity}
end

function default_data(t::Type{ElectricSteam}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{ElectricSteam}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Steam",
            :elec_consumption => 1.0,
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
            :elec_edge => @edge_data(
                :commodity => "Electricity",
                :has_capacity => false,
            ),
        ),
    )
end

function simple_default_data(::Type{ElectricSteam}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :capacity_size => 1.0,
        :timedata => "Electricity",
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
        :elec_consumption => 1.0,
        :ramp_up_fraction => 0.0,
        :ramp_down_fraction => 0.0,
    )
end

function set_commodity!(::Type{ElectricSteam}, commodity::Type{<:Commodity}, data::AbstractDict{Symbol,Any})
    edge_keys = [:elec_edge]
    if haskey(data, :elec_commodity)
        data[:elec_commodity] = string(commodity)
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
    make(::Type{ElectricSteam}, data::AbstractDict{Symbol, Any}, system::System) -> ElectricSteam
"""

function make(asset_type::Type{ElectricSteam}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

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
        location = location,
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

    # Create the steam edge with the appropriate type
    steam_edge = Edge(
        Symbol(id, "_", steam_edge_key),
        steam_edge_data,
        system.time_data[:Steam],
        Steam,
        steam_start_node,
        steam_end_node,
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
    elec_end_node = steam_transform
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )

    steam_transform.balance_data = Dict(
        :energy => Dict(
            steam_edge.id => get(transform_data, :elec_consumption, 1.0),
            elec_edge.id => 1.0,
        ),
    )

    return ElectricSteam(id, steam_transform, steam_edge, elec_edge)
end
