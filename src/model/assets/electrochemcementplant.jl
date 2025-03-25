struct ElectrochemCementPlant{T} <: AbstractAsset
    id::AssetId
    cement_transform::Transformation
    cement_materials_edge::Edge{CementMaterials} # Cement input materials
    elec_edge::Union{Edge{Electricity},EdgeWithUC{Electricity}}
    echem_cement_edge::Edge{Cement} # Cement produced
end

ElectrochemCementPlant(id::AssetId, cement_transform::Transformation, cement_materials_edge::Edge{T}, elec_edge::Union{Edge{Electricity},EdgeWithUC{Electricity}}, echem_cement_edge::Edge{Cement}) where T<:Commodity =
ElectrochemCementPlant{T}(id, cement_transform, cement_materials_edge, elec_edge, echem_cement_edge)

function make(::Type{ElectrochemCementPlant}, data::AbstractDict{Symbol,Any}, system::System)
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

    # Cement Input Materials Edge
    cement_materials_edge_key = :cement_materials_edge
    cement_materials_edge_data = process_data(data[:edges][cement_materials_edge_key])
    T = commodity_types()[Symbol(cement_materials_edge_data[:type])];

    cement_materials_start_node = find_node(system.locations, Symbol(cement_materials_edge_data[:start_vertex]))
    cement_materials_end_node = cement_transform
    cement_materials_edge = Edge(
        Symbol(id, "_", cement_materials_edge_key),
        cement_materials_edge_data,
        system.time_data[Symbol(T)],
        T,
        cement_materials_start_node,
        cement_materials_end_node,
    )
    cement_materials_edge.unidirectional = true;

    # Cement Edge
    echem_cement_edge_key = :echem_cement_edge
    echem_cement_edge_data = process_data(data[:edges][echem_cement_edge_key])
    cement_start_node = cement_transform
    cement_end_node = find_node(system.locations, Symbol(echem_cement_edge_data[:end_vertex]))
    echem_cement_edge = Edge(
        Symbol(id, "_", echem_cement_edge_key),
        echem_cement_edge_data,
        system.time_data[:Cement],
        Cement,
        cement_start_node,
        cement_end_node,
    )
    echem_cement_edge.constraints = get(
            echem_cement_edge_data,
            :constraints,
            [
                CapacityConstraint()
            ],
        )
    echem_cement_edge.unidirectional = true;

    # Balance Constraint Values
    cement_transform.balance_data = Dict(
        :input_materials_to_cement => Dict(
            cement_materials_edge.id => 1.0,
            elec_edge.id => 0,
            echem_cement_edge.id => 1.0
        ),
        :elec_to_cement => Dict(
            cement_materials_edge.id => 0,
            elec_edge.id => 1.0,
            echem_cement_edge.id => get(transform_data, :elec_cement_rate, 1.0)
        )
    )


    return ElectrochemCementPlant(id, cement_transform, cement_materials_edge, elec_edge, echem_cement_edge)
end
