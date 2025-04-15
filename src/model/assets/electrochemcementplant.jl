struct ElectrochemCementPlant <: AbstractAsset
    id::AssetId
    cement_transform::Transformation
    elec_edge::Union{Edge{Electricity},EdgeWithUC{Electricity}}
    cement_edge::Edge{Cement} # Cement produced
end

function default_data(::Type{ElectrochemCementPlant}, id=missing, style="full")
    return Dict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Cement",
            :elec_cement_rate => 1.0,
            :cement_emissions_rate => 0.0,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :elec_edge => @edge_data(
                :commodity => "Electricity"
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
        ),
    )
end

function make(asset_type::Type{ElectrochemCementPlant}, data::AbstractDict{Symbol,Any}, system::System)
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

    # Balance Constraint Values
    cement_transform.balance_data = Dict(
        :elec_to_cement => Dict(
            elec_edge.id => 1.0,
            cement_edge.id => get(transform_data, :elec_cement_rate, 1.0)
        )
    )


    return ElectrochemCementPlant(id, cement_transform, elec_edge, cement_edge)
end
