struct GasStorage{T} <: AbstractAsset
    id::AssetId
    gas_storage::AbstractStorage{T}
    discharge_edge::Edge{T}
    charge_edge::Edge{T}
    discharge_elec_edge::Edge{Electricity}
    charge_elec_edge::Edge{Electricity}
end

GasStorage(id::AssetId,gas_storage::AbstractStorage{T},discharge_edge::Edge{T},charge_edge::Edge{T},discharge_elec_edge::Edge{Electricity},
charge_elec_edge::Edge{Electricity}) where T<:Commodity =
    GasStorage{T}(id,gas_storage,discharge_edge,charge_edge,discharge_elec_edge,charge_elec_edge)

function make(::Type{GasStorage}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    ## Storage component of the gas storage
    gas_storage_key = :storage
    storage_data = process_data(data[gas_storage_key])
    T = commodity_types()[Symbol(storage_data[:commodity])]
    default_constraints = [
        BalanceConstraint(),
        StorageCapacityConstraint(),
    ]

    # check if the storage is a long duration storage
    long_duration = get(storage_data, :long_duration, false)
    StorageType = long_duration ? LongDurationStorage : Storage
    # if storage is long duration, add the corresponding constraint
    if long_duration
        push!(default_constraints, LongDurationStorageImplicitMinMaxConstraint())
    end
    # create the storage component of the gas storage
    gas_storage = StorageType(
        Symbol(id, "_", gas_storage_key),
        storage_data,
        system.time_data[Symbol(T)],
        T,
    )
    gas_storage.constraints = get(storage_data, :constraints, default_constraints)

    charge_edge_key = :charge_edge
    charge_edge_data = process_data(data[:edges][charge_edge_key])
    charge_start_node = find_node(system.locations, Symbol(charge_edge_data[:start_vertex]))
    charge_end_node = gas_storage
    gas_storage_charge = Edge(
        Symbol(id, "_", charge_edge_key),
        charge_edge_data,
        system.time_data[Symbol(T)],
        T,
        charge_start_node,
        charge_end_node,
    )
    gas_storage_charge.has_capacity = get(charge_edge_data, :has_capacity, true)
    gas_storage_charge.unidirectional = true;
    gas_storage_charge.constraints = get(charge_edge_data, :constraints, [CapacityConstraint()])

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
    gas_storage_discharge.has_capacity = get(discharge_edge_data, :has_capacity, true)
    gas_storage_discharge.constraints = get(discharge_edge_data, :constraints,[CapacityConstraint(),RampingLimitConstraint()])
    gas_storage_discharge.unidirectional = true;

    gas_storage.discharge_edge = gas_storage_discharge
    gas_storage.charge_edge = gas_storage_charge

    discharge_elec_edge_key = :discharge_elec_edge
    discharge_elec_edge_data = process_data(data[:edges][discharge_elec_edge_key])
    elec_start_node =
        find_node(system.locations, Symbol(discharge_elec_edge_data[:start_vertex]))
    elec_end_node = gas_storage
    discharge_elec_edge = Edge(
        Symbol(id, "_", discharge_elec_edge_key),
        discharge_elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    discharge_elec_edge.unidirectional = true;
    discharge_elec_edge.has_capacity = false;
    discharge_elec_edge.constraints = Vector{AbstractTypeConstraint}()

    charge_elec_edge_key = :charge_elec_edge
    charge_elec_edge_data = process_data(data[:edges][charge_elec_edge_key])
    elec_start_node = find_node(system.locations, Symbol(charge_elec_edge_data[:start_vertex]))
    elec_end_node = gas_storage
    charge_elec_edge = Edge(
        Symbol(id, "_", charge_elec_edge_key),
        charge_elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    charge_elec_edge.unidirectional = true;
    charge_elec_edge.has_capacity = false;
    charge_elec_edge.constraints = Vector{AbstractTypeConstraint}()
   

    gas_storage.balance_data = Dict(
        :storage => Dict(
            gas_storage_discharge.id => 1 / get(discharge_edge_data, :efficiency, 1.0),
            gas_storage_charge.id => get(charge_edge_data, :efficiency, 1.0),
        ),
        :charge_electricity_consumption => Dict(
            #This is multiplied by -1 because they are both edges that enters storage, 
            #so we need to get one of them on the right side of the equality balance constraint    
            charge_elec_edge.id => -1.0,
            gas_storage_charge.id => get(storage_data, :charge_electricity_consumption, 0.0), 
        ),
        :discharge_electricity_consumption => Dict(
            discharge_elec_edge.id => 1.0,
            gas_storage_discharge.id => get(storage_data, :discharge_electricity_consumption, 0.0),
        ),
    )

    return GasStorage(
        id,
        gas_storage,
        gas_storage_discharge,
        gas_storage_charge,
        discharge_elec_edge,
        charge_elec_edge,
    )
end
