struct VRE <: AbstractAsset
    id::AssetId
    energy_transform::Transformation
    edge::Edge{<:Electricity}
end

function default_data(t::Type{VRE}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{VRE}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Electricity",
        ),
        :edges => Dict{Symbol, Any}(
            :edge => @edge_data(
                :commodity => "Electricity",
                :has_capacity => true,
                :can_expand => true,
                :can_return => true,
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                )
            ),
        ),
    )
end

function simple_default_data(::Type{VRE}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
        :availability => Dict{Symbol,Any}(
            :timeseries => Dict{Symbol,Any}(
                :path => "system/availability.csv",
                :header => missing,
            )
        )
    )
end

"""
    make(::Type{<:VRE}, data::AbstractDict{Symbol, Any}, system::System) -> VRE
    
    VRE is an alias for Union{SolarPV, WindTurbine}

    Necessary data fields:
     - transforms: Dict{Symbol, Any}
        - id: String
        - timedata: String
    - edges: Dict{Symbol, Any}
        - edge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_capacity: Bool
            - can_retire: Bool
            - can_expand: Bool
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(asset_type::Type{<:VRE}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    energy_key = :transforms
    @process_data(
        transform_data, 
        data[energy_key], 
        [
            (data[energy_key], key),
            (data[energy_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    vre_transform = Transformation(;
        id = Symbol(id, "_", energy_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        location = location,
    )

    elec_edge_key = :edge
    @process_data(
        elec_edge_data,
        data[:edges][elec_edge_key],
        [
            (data[:edges][elec_edge_key], key),
            (data[:edges][elec_edge_key], Symbol("elec_", key)),
            (data, Symbol("elec_", key)),
            (data, key),
        ],
    )

    elec_start_node = vre_transform
    @end_vertex(
        elec_end_node,
        elec_edge_data,
        Electricity,
        [(elec_edge_data, :end_vertex), (data, :location)]
    )
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )

    return asset_type(id, vre_transform, elec_edge)
end
