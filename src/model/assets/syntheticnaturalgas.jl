struct SyntheticNaturalGas <: AbstractAsset
    id::AssetId
    synthetic_natural_gas_transform::Transformation
    co2_captured_edge::Edge{CO2Captured}
    natgas_edge::Edge{NaturalGas}
    elec_edge::Edge{Electricity}
    h2_edge::Edge{Hydrogen}
    co2_emission_edge::Edge{CO2}
end

function make(::Type{SyntheticNaturalGas}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    synthetic_natural_gas_transform_key = :transforms
    transform_data = process_data(data[synthetic_natural_gas_transform_key])
    synthetic_natural_gas_transform = Transformation(;
        id = Symbol(id, "_", synthetic_natural_gas_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    co2_captured_edge_key = :co2_captured_edge
    co2_captured_edge_data = process_data(data[:edges][co2_captured_edge_key])
    co2_captured_start_node = find_node(system.locations, Symbol(co2_captured_edge_data[:start_vertex]))
    co2_captured_end_node = synthetic_natural_gas_transform
    co2_captured_edge = Edge(
        Symbol(id, "_", co2_captured_edge_key),
        co2_captured_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_captured_start_node,
        co2_captured_end_node,
    )
    co2_captured_edge.constraints = get(co2_captured_edge_data, :constraints, [CapacityConstraint()])
    co2_captured_edge.unidirectional = get(co2_captured_edge_data, :unidirectional, true)

    natgas_edge_key = :natgas_edge
    natgas_edge_data = process_data(data[:edges][natgas_edge_key])
    natgas_start_node = synthetic_natural_gas_transform
    natgas_end_node = find_node(system.locations, Symbol(natgas_edge_data[:end_vertex]))
    natgas_edge = Edge(
        Symbol(id, "_", natgas_edge_key),
        natgas_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        natgas_start_node,
        natgas_end_node,
    )
    natgas_edge.constraints = Vector{AbstractTypeConstraint}()
    natgas_edge.unidirectional = true;
    natgas_edge.has_capacity = false;

    elec_edge_key = :elec_edge
    elec_edge_data = process_data(data[:edges][elec_edge_key])
    elec_end_node = synthetic_natural_gas_transform
    elec_start_node = find_node(system.locations, Symbol(elec_edge_data[:start_vertex]))
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    elec_edge.constraints = Vector{AbstractTypeConstraint}()
    elec_edge.unidirectional = true;
    elec_edge.has_capacity = false;

    h2_edge_key = :h2_edge
    h2_edge_data = process_data(data[:edges][h2_edge_key])
    h2_end_node = synthetic_natural_gas_transform
    h2_start_node = find_node(system.locations, Symbol(h2_edge_data[:start_vertex]))
    h2_edge = Edge(
        Symbol(id, "_", h2_edge_key),
        h2_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_start_node,
        h2_end_node,
    )
    h2_edge.constraints = Vector{AbstractTypeConstraint}()
    h2_edge.unidirectional = true;
    h2_edge.has_capacity = false;

    co2_emission_edge_key = :co2_emission_edge
    co2_emission_edge_data = process_data(data[:edges][co2_emission_edge_key])
    co2_emission_start_node = synthetic_natural_gas_transform
    co2_emission_end_node = find_node(system.locations, Symbol(co2_emission_edge_data[:end_vertex]))
    co2_emission_edge = Edge(
        Symbol(id, "_", co2_emission_edge_key),
        co2_emission_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_emission_start_node,
        co2_emission_end_node,
    )
    co2_emission_edge.constraints = Vector{AbstractTypeConstraint}()
    co2_emission_edge.unidirectional = true;
    co2_emission_edge.has_capacity = false;

    synthetic_natural_gas_transform.balance_data = Dict(
        :natgas_production => Dict(
            natgas_edge.id => 1.0,
            co2_captured_edge.id => get(transform_data, :natgas_production, 0.0)
        ),
        :elec_consumption => Dict(
            elec_edge.id => -1.0,
            co2_captured_edge.id => get(transform_data, :electricity_consumption, 0.0)
        ),
        :h2_consumption => Dict(
            h2_edge.id => -1.0,
            co2_captured_edge.id => get(transform_data, :h2_consumption, 0.0)
        ),
        :emissions => Dict(
            co2_captured_edge.id => get(transform_data, :emission_rate, 1.0),
            co2_emission_edge.id => 1.0
        )
    )

    return SyntheticNaturalGas(id, synthetic_natural_gas_transform, co2_captured_edge,natgas_edge,elec_edge,h2_edge,co2_emission_edge) 
end
