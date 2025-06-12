struct TransmissionLink{T} <: AbstractAsset
    id::AssetId
    transmission_edge::Edge{<:T}
end

TransmissionLink(id::AssetId, transmission_edge::Edge{T}) where T<:Commodity = TransmissionLink{T}(id, transmission_edge)

function default_data(t::Type{TransmissionLink}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{TransmissionLink}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :edges => Dict{Symbol,Any}(
            :transmission_edge => @edge_data(
                :commodity => missing,
                :unidirectional => false,
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

function simple_default_data(::Type{TransmissionLink}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => false,
        :existing_capacity => 0.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
        :distance => 0.0,
        :unidirectional => false,
        :loss_fraction => 0.0,
    )
end

function set_commodity!(::Type{TransmissionLink}, commodity::Type{<:Commodity}, data::AbstractDict{Symbol,Any})
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
    make(::Type{TransmissionLink}, data::AbstractDict{Symbol, Any}, system::System) -> TransmissionLink
"""

function make(asset_type::Type{<:TransmissionLink}, data::AbstractDict{Symbol,Any}, system::System)
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
        [(transmission_edge_data, :start_vertex), (data, :transmission_origin), (data, :location)],
    )
    @end_vertex(
        t_end_node,
        transmission_edge_data,
        commodity,
        [(transmission_edge_data, :end_vertex), (data, :transmission_dest), (data, :location)],
    )

    transmission_edge = Edge(
        Symbol(id, "_", transmission_edge_key),
        transmission_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        t_start_node,
        t_end_node,
    )
    return TransmissionLink(id, transmission_edge)
end
