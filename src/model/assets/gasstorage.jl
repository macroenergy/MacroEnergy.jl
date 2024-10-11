struct GasStorage{T} <: AbstractAsset
    id::AssetId
    gasstorage_transform::Storage{T}
    compressor_transform::Transformation
    discharge_edge::Edge{T}
    charge_edge::Edge{T}
    compressor_elec_edge::Edge{Electricity}
    compressor_gas_edge::Edge{T}
end

GasStorage(id::AssetId,gasstorage_transform::Storage{T},compressor_transform::Transformation,discharge_edge::Edge{T},charge_edge::Edge{T},compressor_elec_edge::Edge{Electricity},
compressor_gas_edge::Edge{T})where T<:Commodity =
    GasStorage{T}(id,gasstorage_transform,compressor_transform,discharge_edge,charge_edge,compressor_elec_edge,
    compressor_gas_edge)

function make(::Type{GasStorage}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    gasstorage_key = :storage
    storage_data = process_data(data[gasstorage_key])
    T = commodity_types()[Symbol(storage_data[:commodity])];

    gasstorage = Storage(
        Symbol(id, "_", gasstorage_key),
        storage_data,
        system.time_data[Symbol(T)],
        T,
    )
    gasstorage.constraints = get(
        storage_data,
        :constraints,
        [BalanceConstraint(), StorageCapacityConstraint()],
    )

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

    compressor_gas_edge_key = :compressor_gas_edge
    compressor_gas_edge_data = process_data(data[:edges][compressor_gas_edge_key])
    gas_edge_start_node =
        find_node(system.locations, Symbol(compressor_gas_edge_data[:start_vertex]))
    gas_edge_end_node = compressor_transform
    compressor_gas_edge = Edge(
        Symbol(id, "_", compressor_gas_edge_key),
        compressor_gas_edge_data,
        system.time_data[Symbol(T)],
        T,
        gas_edge_start_node,
        gas_edge_end_node,
    )
    compressor_gas_edge.unidirectional = true;

    charge_edge_key = :charge_edge
    charge_edge_data = process_data(data[:edges][charge_edge_key])
    charge_start_node = compressor_transform
    charge_end_node = gasstorage
    gasstorage_charge = Edge(
        Symbol(id, "_", charge_edge_key),
        charge_edge_data,
        system.time_data[Symbol(T)],
        T,
        charge_start_node,
        charge_end_node,
    )
    gasstorage_charge.unidirectional = true;
    gasstorage_charge.constraints =
        get(charge_edge_data, :constraints, [CapacityConstraint()])

    discharge_edge_key = :discharge_edge
    discharge_edge_data = process_data(data[:edges][discharge_edge_key])
    discharge_start_node = gasstorage
    discharge_end_node =
        find_node(system.locations, Symbol(discharge_edge_data[:end_vertex]))
    gasstorage_discharge = Edge(
        Symbol(id, "_", discharge_edge_key),
        discharge_edge_data,
        system.time_data[Symbol(T)],
        T,
        discharge_start_node,
        discharge_end_node,
    )
    gasstorage_discharge.constraints = get(
        discharge_edge_data,
        :constraints,
        [CapacityConstraint()],
    )
    gasstorage_discharge.unidirectional = true;

    gasstorage.discharge_edge = gasstorage_discharge
    gasstorage.charge_edge = gasstorage_charge

    gasstorage.balance_data = Dict(
        :storage => Dict(
            gasstorage_discharge.id => 1 / get(discharge_edge_data, :efficiency, 1.0),
            gasstorage_charge.id => get(charge_edge_data, :efficiency, 1.0),
        ),
    )

    compressor_transform.balance_data = Dict(
        :electricity => Dict(
            compressor_gas_edge.id => get(transform_data, :electricity_consumption, 0.0),
            compressor_elec_edge.id => 1.0,
            gasstorage_charge.id => 0.0,
        ),
        :hydrogen => Dict(
            gasstorage_charge.id => 1.0,
            compressor_gas_edge.id => 1.0,
            compressor_elec_edge.id => 0.0,
        ),
    )

    return GasStorage(
        id,
        gasstorage,
        compressor_transform,
        gasstorage_discharge,
        gasstorage_charge,
        compressor_elec_edge,
        compressor_gas_edge,
    )
end
