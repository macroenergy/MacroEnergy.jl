struct ElectrochemCementPlant_test{T} <: AbstractAsset
    id::AssetId
    cement_transform::Transformation
    elec_edge::Union{Edge{Electricity},EdgeWithUC{Electricity}}
    cement_edge::Edge{Cement} # Cement produced
end

ElectrochemCementPlant_test(id::AssetId, cement_transform::Transformation, elec_edge::Union{Edge{Electricity},EdgeWithUC{Electricity}}, cement_edge::Edge{Cement}) = 
ElectrochemCementPlant_test{Nothing}(id, cement_transform, elec_edge, cement_edge)

function make(::Type{ElectrochemCementPlant_test}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    # Cement Transformation
    cement_key = :transforms
    transform_data = process_data(data[cement_key])
    cement_transform = Transformation(;
        id = Symbol(id, "_", cement_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    # Electricity Edge
    elec_edge_key = :elec_edge
    elec_edge_data = process_data(data[:edges][elec_edge_key])
    elec_start_node = find_node(system.locations, Symbol(elec_edge_data[:start_vertex]))
    elec_end_node = cement_transform

    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    elec_edge.unidirectional = true;

    # Cement Edge
    cement_edge_key = :cement_edge
    cement_edge_data = process_data(data[:edges][cement_edge_key])
    cement_start_node = cement_transform
    cement_end_node = find_node(system.locations, Symbol(cement_edge_data[:end_vertex]))
    cement_edge = Edge(
        Symbol(id, "_", cement_edge_key),
        cement_edge_data,
        system.time_data[:Cement],
        Cement,
        cement_start_node,
        cement_end_node,
    )
    cement_edge.constraints = get(
            cement_edge_data,
            :constraints,
            [
                CapacityConstraint()
            ],
        )
    cement_edge.unidirectional = true;

    # Balance Constraint Values
    cement_transform.balance_data = Dict(
        :elec_to_cement => Dict(
            elec_edge.id => 1.0,
            cement_edge.id => get(transform_data, :elec_cement_rate, 1.0)
        )
    )


    return ElectrochemCementPlant_test(id, cement_transform, elec_edge, cement_edge)
end
