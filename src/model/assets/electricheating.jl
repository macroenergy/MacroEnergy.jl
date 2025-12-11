struct ElectricHeating <: AbstractAsset
    id::AssetId
    heating_transform::Transformation
    heat_edge::Edge{<:Heat}
    elec_edge::Edge{<:Electricity}
end

function default_data(t::Type{ElectricHeating}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{ElectricHeating}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Heat",
            :elec_consumption => 1.0,
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
            :elec_edge => @edge_data(
                :commodity => "Electricity",
                :has_capacity => false,
            ),
        ),
    )
end

function simple_default_data(::Type{ElectricHeating}, id=missing)
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

function set_commodity!(::Type{ElectricHeating}, commodity::Type{<:Commodity}, data::AbstractDict{Symbol,Any})
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
    make(::Type{ElectricHeating}, data::AbstractDict{Symbol, Any}, system::System) -> ElectricHeating
"""

function make(asset_type::Type{ElectricHeating}, data::AbstractDict{Symbol,Any}, system::System)
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

    # Create the heat edge with the appropriate type
    heat_edge = Edge(
        Symbol(id, "_", heat_edge_key),
        heat_edge_data,
        system.time_data[:Heat],
        Heat,
        heat_start_node,
        heat_end_node,
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
    elec_end_node = heating_transform
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )

    heating_transform.balance_data = Dict(
        :energy => Dict(
            heat_edge.id => get(transform_data, :elec_consumption, 1.0),
            elec_edge.id => 1.0,
        ),
    )

    return ElectricHeating(id, heating_transform, heat_edge, elec_edge)
end
