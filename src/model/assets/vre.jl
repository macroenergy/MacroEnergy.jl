struct SolarPV <: AbstractAsset
    id::AssetId
    energy_transform::Transformation
    edge::Edge{Electricity}
end

struct WindTurbine <: AbstractAsset
    id::AssetId
    energy_transform::Transformation
    edge::Edge{Electricity}
end


const VRE = Union{SolarPV,WindTurbine}

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

    energy_key = :transforms
    transform_data = process_data(data[energy_key])
    vre_transform = Transformation(;
        id = Symbol(id, "_", energy_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
    )

    elec_edge_key = :edge
    elec_edge_data = process_data(data[:edges][elec_edge_key])
    elec_start_node = vre_transform
    elec_end_node = find_node(system.locations, Symbol(elec_edge_data[:end_vertex]))
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    elec_edge.constraints = get(elec_edge_data, :constraints, [CapacityConstraint()])
    elec_edge.unidirectional = get(elec_edge_data, :unidirectional, true)

    return asset_type(id, vre_transform, elec_edge)
end
