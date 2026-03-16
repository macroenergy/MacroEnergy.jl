struct SyntheticAmmonia <: AbstractAsset
    id::AssetId
    synthetic_ammonia_transform::Transformation
    h2_edge::Edge{<:Hydrogen} ## MWh
    n2_edge::Edge{<:Nitrogen} ## tonnes
    elec_edge::Edge{<:Electricity} ## MWh
    nh3_edge::Edge{<:Ammonia} ## MWh
end

function default_data(t::Type{SyntheticAmmonia}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{SyntheticAmmonia}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Ammonia",
            :h2_consumption => 0.0,
            :n2_consumption => 0.0,
            :electricity_consumption => 0.0,
            :investment_cost => 0.0,
            :fixed_om_cost => 0.0,
            :variable_om_cost => 0.0,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :h2_edge => @edge_data(
                :commodity => "Hydrogen",
            ),
            :n2_edge => @edge_data(
                :commodity => "Nitrogen",
            ),
            :elec_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :nh3_edge => @edge_data(
                :commodity => "Ammonia",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true
                ),
            ),
        ),
    )
end

function simple_default_data(::Type{SyntheticAmmonia}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :h2_consumption => 0.0,
        :n2_consumption => 0.0,
        :electricity_consumption => 0.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

function make(asset_type::Type{SyntheticAmmonia}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    synthetic_ammonia_transform_key = :transforms
    @process_data(
        transform_data, 
        data[synthetic_ammonia_transform_key], 
        [
            (data[synthetic_ammonia_transform_key], key),
            (data[synthetic_ammonia_transform_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    synthetic_ammonia_transform = Transformation(;
        id = Symbol(id, "_", synthetic_ammonia_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        location = location,
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    h2_edge_key = :h2_edge
    @process_data(
        h2_edge_data, 
        data[:edges][h2_edge_key], 
        [
            (data[:edges][h2_edge_key], key),
            (data[:edges][h2_edge_key], Symbol("h2_", key)),
            (data, Symbol("h2_", key)),
        ]
    )
    @start_vertex(
        h2_start_node,
        h2_edge_data,
        Hydrogen,
        [(h2_edge_data, :start_vertex), (data, :location)],
    )
    h2_end_node = synthetic_ammonia_transform
    h2_edge = Edge(
        Symbol(id, "_", h2_edge_key),
        h2_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_start_node,
        h2_end_node,
    )

    n2_edge_key = :n2_edge
    @process_data(
        n2_edge_data, 
        data[:edges][n2_edge_key], 
        [
            (data[:edges][n2_edge_key], key),
            (data[:edges][n2_edge_key], Symbol("n2_", key)),
            (data, Symbol("n2_", key)),
        ]
    )
    @start_vertex(
        n2_start_node,
        n2_edge_data,
        Nitrogen,
        [(n2_edge_data, :start_vertex), (data, :location)],
    )
    n2_end_node = synthetic_ammonia_transform
    n2_edge = Edge(
        Symbol(id, "_", n2_edge_key),
        n2_edge_data,
        system.time_data[:Nitrogen],
        Nitrogen,
        n2_start_node,
        n2_end_node,
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
    elec_end_node = synthetic_ammonia_transform
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )

    nh3_edge_key = :nh3_edge
    @process_data(
        nh3_edge_data, 
        data[:edges][nh3_edge_key], 
        [
            (data[:edges][nh3_edge_key], key),
            (data[:edges][nh3_edge_key], Symbol("nh3_", key)),
            (data, Symbol("nh3_", key)),
        ]
    )
    nh3_start_node = synthetic_ammonia_transform
    @end_vertex(
        nh3_end_node,
        nh3_edge_data,
        Ammonia,
        [(nh3_edge_data, :end_vertex), (data, :location)],
    )
    nh3_edge = Edge(
        Symbol(id, "_", nh3_edge_key),
        nh3_edge_data,
        system.time_data[:Ammonia],
        Ammonia,
        nh3_start_node,
        nh3_end_node,
    )

    synthetic_ammonia_transform.balance_data = Dict(
        :hydrogen => Dict(
            nh3_edge.id => get(transform_data, :h2_consumption, 0.0),
            h2_edge.id => 1.0,
        ),
        :nitrogen => Dict(
            nh3_edge.id => get(transform_data, :n2_consumption, 0.0),
            n2_edge.id => 1.0,
        ),
        :electricity => Dict(
            nh3_edge.id => get(transform_data, :electricity_consumption, 0.0),
            elec_edge.id => 1.0
        ),
    )

    return SyntheticAmmonia(id, synthetic_ammonia_transform, h2_edge, n2_edge, elec_edge, nh3_edge)
end 