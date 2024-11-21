struct GasStorage{T} <: AbstractAsset
    id::AssetId
    gas_storage::AbstractStorage{T}
    compressor_transform::Transformation
    discharge_edge::Edge{T}
    charge_edge::Edge{T}
    compressor_elec_edge::Edge{Electricity}
    compressor_gas_edge::Edge{T}
end

GasStorage(id::AssetId,gas_storage::AbstractStorage{T},compressor_transform::Transformation,discharge_edge::Edge{T},charge_edge::Edge{T},compressor_elec_edge::Edge{Electricity},
compressor_gas_edge::Edge{T}) where T<:Commodity =
    GasStorage{T}(id,gas_storage,compressor_transform,discharge_edge,charge_edge,compressor_elec_edge,
    compressor_gas_edge)

function make(::Type{GasStorage}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    gas_storage_key = :storage
    storage_data = process_data(data[gas_storage_key])
    T = commodity_types()[Symbol(storage_data[:commodity])];
    long_duration = get(storage_data, :long_duration, false)
    if long_duration==true
        gas_storage = LongDurationStorage(
            Symbol(id, "_", gas_storage_key),
            storage_data,
            system.time_data[Symbol(T)],
            T,
        )
        gas_storage.constraints = get(
        storage_data,
        :constraints,
        [BalanceConstraint(), StorageCapacityConstraint(),LongDurationStorageImplicitMinMaxConstraint()],
    )
    else
        gas_storage = Storage(
            Symbol(id, "_", gas_storage_key),
            storage_data,
            system.time_data[Symbol(T)],
            T,
        )
        gas_storage.constraints = get(
        storage_data,
        :constraints,
        [BalanceConstraint(), StorageCapacityConstraint()],
    )
    end
    

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
    charge_end_node = gas_storage
    gas_storage_charge = Edge(
        Symbol(id, "_", charge_edge_key),
        charge_edge_data,
        system.time_data[Symbol(T)],
        T,
        charge_start_node,
        charge_end_node,
    )
    gas_storage_charge.unidirectional = true;
    gas_storage_charge.constraints =
        get(charge_edge_data, :constraints, [CapacityConstraint()])

    discharge_edge_key = :discharge_edge
    discharge_edge_data = process_data(data[:edges][discharge_edge_key])
    discharge_start_node = gas_storage
    discharge_end_node =
        find_node(system.locations, Symbol(discharge_edge_data[:end_vertex]))
    gas_storage_discharge = Edge(
        Symbol(id, "_", discharge_edge_key),
        discharge_edge_data,
        system.time_data[Symbol(T)],
        T,
        discharge_start_node,
        discharge_end_node,
    )
    gas_storage_discharge.constraints = get(
        discharge_edge_data,
        :constraints,
        [CapacityConstraint()],
    )
    gas_storage_discharge.unidirectional = true;

    gas_storage.discharge_edge = gas_storage_discharge
    gas_storage.charge_edge = gas_storage_charge

    gas_storage.balance_data = Dict(
        :storage => Dict(
            gas_storage_discharge.id => 1 / get(discharge_edge_data, :efficiency, 1.0),
            gas_storage_charge.id => get(charge_edge_data, :efficiency, 1.0),
        ),
    )

    compressor_transform.balance_data = Dict(
        :electricity => Dict(
            compressor_elec_edge.id => 1.0,
            gas_storage_charge.id => get(transform_data, :electricity_consumption, 0.0),
        ),
        :hydrogen => Dict(
            gas_storage_charge.id => 1.0,
            compressor_gas_edge.id => 1.0
        ),
    )

    return GasStorage(
        id,
        gas_storage,
        compressor_transform,
        gas_storage_discharge,
        gas_storage_charge,
        compressor_elec_edge,
        compressor_gas_edge,
    )
end
