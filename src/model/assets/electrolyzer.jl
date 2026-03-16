struct Electrolyzer <: AbstractAsset
    id::AssetId
    electrolyzer_transform::Transformation
    h2_edge::Edge{<:Hydrogen}
    elec_edge::Edge{<:Electricity}
end

function default_data(t::Type{Electrolyzer}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{Electrolyzer}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Electricity",
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
            :efficiency_rate => 0.0
        ),
        :edges => Dict{Symbol,Any}(
            :h2_edge => @edge_data(
                :commodity => "Hydrogen",
                :has_capacity => true,
                :can_retire => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true,
                ),
            ),
            :elec_edge => @edge_data(
                :commodity => "Electricity",
            ),
        ),
    )
end

function simple_default_data(::Type{Electrolyzer}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :capacity_size => 1.0,
        :efficiency_rate => 0.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

"""
    make(::Type{Electrolyzer}, data::AbstractDict{Symbol, Any}, system::System) -> Electrolyzer

    Necessary data fields:
     - transforms: Dict{Symbol, Any}
        - id: String
        - timedata: String
        - efficiency_rate: Float64
        - constraints: Vector{AbstractTypeConstraint}
    - edges: Dict{Symbol, Any}
        - h2_edge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_capacity: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
        - e_edge: Dict{Symbol, Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_capacity: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(asset_type::Type{Electrolyzer}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    electrolyzer_key = :transforms
    @process_data(
        transform_data, 
        data[electrolyzer_key], 
        [
            (data[electrolyzer_key], key),
            (data[electrolyzer_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    electrolyzer = Transformation(;
        id = Symbol(id, "_", electrolyzer_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        location = location,
        constraints = transform_data[:constraints],
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
    elec_end_node = electrolyzer
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )

    h2_edge_key = :h2_edge
    @process_data(
        h2_edge_data, 
        data[:edges][h2_edge_key], 
        [
            (data[:edges][h2_edge_key], key),
            (data[:edges][h2_edge_key], Symbol("h2_", key)),
            (data, Symbol("h2_", key)),
            (data, key),
        ]
    )
    h2_start_node = electrolyzer
    @end_vertex(
        h2_end_node,
        h2_edge_data,
        Hydrogen,
        [(h2_edge_data, :end_vertex), (data, :location)],
    )
    h2_edge = Edge(
        Symbol(id, "_", h2_edge_key),
        h2_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_start_node,
        h2_end_node,
    )

    electrolyzer.balance_data = Dict(
        :energy => Dict(
            h2_edge.id => 1.0,
            elec_edge.id => get(transform_data, :efficiency_rate, 1.0),
        ),
    )

    return Electrolyzer(id, electrolyzer, h2_edge, elec_edge)
end
