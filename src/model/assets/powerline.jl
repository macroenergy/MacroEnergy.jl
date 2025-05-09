struct PowerLine <: AbstractAsset
    id::AssetId
    elec_edge::Edge{<:Electricity}
end

function default_data(t::Type{PowerLine}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{PowerLine}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :edges => Dict{Symbol,Any}(
            :elec_edge => @edge_data(
                :commodity => "Electricity",
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

function simple_default_data(::Type{PowerLine}, id=missing)
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


"""
    make(::Type{PowerLine}, data::AbstractDict{Symbol, Any}, system::System) -> PowerLine
"""

function make(asset_type::Type{<:PowerLine}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id]) 

    @setup_data(asset_type, data, id)

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
        [(elec_edge_data, :start_vertex), (data, :line_origin), (data, :location)],
    )
    @end_vertex(
        elec_end_node,
        elec_edge_data,
        Electricity,
        [(elec_edge_data, :end_vertex), (data, :line_dest), (data, :location)],
    )
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    return PowerLine(id, elec_edge)
end
