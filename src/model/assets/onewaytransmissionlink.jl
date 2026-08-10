struct OneWayTransmissionLink{T} <: AbstractAsset
    id::AssetId
    transmission_edge::UnidirectionalEdge{<:T}
end

OneWayTransmissionLink(id::AssetId, transmission_edge::UnidirectionalEdge{T}) where T<:Commodity = OneWayTransmissionLink{T}(id, transmission_edge)

function default_data(t::Type{OneWayTransmissionLink}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{OneWayTransmissionLink}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :edges => Dict{Symbol,Any}(
            :transmission_edge => @edge_data(
                :commodity => missing,
                :unidirectional => true,
                :has_capacity => true,
                :can_expand => true,
                :can_retire => false,
                :loss_fraction => 0.0,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true,
                ),
            ),
        ),
    )
end

function simple_default_data(::Type{OneWayTransmissionLink}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :commodity => "Electricity",
        :can_expand => true,
        :can_retire => false,
        :existing_capacity => 0.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
        :distance => 0.0,
        :unidirectional => true,
        :loss_fraction => 0.0,
    )
end

function set_commodity!(::Type{OneWayTransmissionLink}, commodity::Type{<:Commodity}, data::AbstractDict{Symbol,Any})
    if haskey(data, :commodity)
        data[:commodity] = string(commodity)
    end
    if haskey(data, :edges)
        if haskey(data[:edges], :transmission_edge)
            if haskey(data[:edges][:transmission_edge], :commodity)
                data[:edges][:transmission_edge][:commodity] = string(commodity)
            end
        end
    end
end

"""
    make(::Type{OneWayTransmissionLink}, data::AbstractDict{Symbol, Any}, system::System) -> OneWayTransmissionLink
"""

function make(asset_type::Type{<:OneWayTransmissionLink}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id]) 

    @setup_data(asset_type, data, id)

    transmission_edge_key = :transmission_edge
    @process_data(
        transmission_edge_data,
        data[:edges][transmission_edge_key],
        [
            (data[:edges][transmission_edge_key], key),
            (data[:edges][transmission_edge_key], Symbol("transmission_", key)),
            (data, Symbol("transmission_", key)),
            (data, key), 
        ]
    )

    commodity_symbol = Symbol(transmission_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    
    @start_vertex(
        t_start_node,
        transmission_edge_data,
        commodity,
        [(transmission_edge_data, :start_vertex), (data, :transmission_origin)],
    )
    @end_vertex(
        t_end_node,
        transmission_edge_data,
        commodity,
        [(transmission_edge_data, :end_vertex), (data, :transmission_dest)],
    )

    if t_start_node == t_end_node
        @warn "OneWayTransmissionLink $id has identical start and end vertices: $(t_start_node.id)."
    end

    transmission_edge = Edge(
        Symbol(id, "_", transmission_edge_key),
        transmission_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        t_start_node,
        t_end_node,
    )
    return OneWayTransmissionLink(id, transmission_edge)
end
