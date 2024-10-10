struct GasPipeline{T} <: AbstractAsset
    id::AssetId
    compressor_transform::Transformation
    output_edge::Edge{T}
    input_edge::Edge{T}
    compressor_elec_edge::Edge{Electricity}
end

GasPipeline(id::AssetId, compressor_transform::Transformation, output_edge::Edge{T}, input_edge::Edge{T}, compressor_elec_edge::Edge{Electricity}) where T<:Commodity =
    GasPipeline{T}(id, compressor_transform, output_edge, input_edge, compressor_elec_edge)

function make(::Type{GasPipeline}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    compressor_key = :transforms
    transform_data = process_data(data[compressor_key])
    compressor_transform = Transformation(;
        id = Symbol(id, "_", compressor_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    compressor_elec_edge_key = :compressor_elec_edge
    compressor_elec_edge_data = process_data(data[:edges][compressor_elec_edge_key])
    elec_start_node =
        find_node(system.locations, Symbol(compressor_elec_edge_data[:start_vertex]))
    elec_end_node = compressor_transform
    compressor_elec_edge = Edge(
        Symbol(id, "_", compressor_elec_edge_key),
        compressor_elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    compressor_elec_edge.unidirectional = true;

    input_edge_key = :input_edge
    input_edge_data = process_data(data[:edges][input_edge_key])
    T = commodity_types()[Symbol(input_edge_data[:type])];

    input_start_node = find_node(system.locations, Symbol(input_edge_data[:start_vertex]))
    input_end_node = compressor_transform
    gaspipeline_input = Edge(
        Symbol(id, "_", input_edge_key),
        input_edge_data,
        system.time_data[Symbol(T)],
        T,
        input_start_node,
        input_end_node,
    )
    gaspipeline_input.unidirectional = true;

    output_edge_key = :output_edge
    output_edge_data = process_data(data[:edges][output_edge_key])
    output_start_node = compressor_transform
    output_end_node = find_node(system.locations, Symbol(output_edge_data[:end_vertex]))
    gaspipeline_output = Edge(
        Symbol(id, "_", output_edge_key),
        output_edge_data,
        system.time_data[T],
        T,
        output_start_node,
        output_end_node,
    )
    gaspipeline_output.constraints = get(
        discharge_edge_data,
        :constraints,
        [CapacityConstraint()],
    )
    gaspipeline_output.unidirectional = true;

    compressor_transform.balance_data = Dict(
        :electricity => Dict(
            gaspipeline_output.id => get(transform_data, :electricity_consumption, 0.0),
            compressor_elec_edge.id => 1.0,
            gaspipeline_input.id => 0.0,
        ),
        :hydrogen => Dict(
            gaspipeline_output.id => 1.0,
            compressor_h2_edge.id => 0.0,
            gaspipeline_input.id => 1.0,
        ),
    )

    return GasPipeline{T}(
        id,
        compressor_transform,
        gaspipeline_output,
        gaspipeline_input,
        compressor_elec_edge
    )

end
