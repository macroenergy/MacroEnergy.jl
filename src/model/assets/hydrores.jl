struct HydroRes <: AbstractAsset
    id::AssetId
    hydrostor::Storage{Electricity}
    discharge_edge::Edge{Electricity}
    inflow_edge::Edge{Electricity}
    spill_edge::Edge{Electricty}
end

function make(::Type{HydroRes}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    storage_key = :storage
    storage_data = process_data(data[storage_key])

    hydrostor = Storage(
        Symbol(id, "_", gas_storage_key),
        storage_data,
        system.time_data[:Electricity],
        Electricity,
    )
    hydrostor.constraints = get(
        storage_data,
        :constraints,
        [BalanceConstraint(), StorageCapacityConstraint(),StorageMinDurationConstraint(),StorageMaxDurationConstraint(),HydroSymmetricCapacityConstraint()],
    )

    discharge_edge_key = :discharge_edge
    discharge_edge_data = process_data(data[:edges][discharge_edge_key])
    discharge_start_node = hydrostor
    discharge_end_node = find_node(system.locations, Symbol(discharge_edge_data[:end_vertex]))
    discharge_edge = Edge(
        Symbol(id, "_", discharge_edge_key),
        discharge_edge_data,
        system.time_data[:Electricity],
        Electricity,
        discharge_start_node,
        discharge_end_node,
    )
    discharge_edge.unidirectional = true;
    discharge_edge.has_capacity = true;
    discharge_edge.constraints = get(discharge_edge_data, :constraints, [CapacityConstraint(),
    RampingLimitConstraint(),StorageDischargeLimitConstraint()])

    inflow_edge_key = :inflow_edge
    inflow_edge_data = process_data(data[:edges][inflow_edge_key])
    inflow_start_node = find_node(system.locations, Symbol(inflow_edge_data[:start_vertex]))
    inflow_end_node = hydrostor
    inflow_edge = Edge(
        Symbol(id, "_", inflow_edge_key),
        inflow_edge_data,
        system.time_data[:Electricity],
        Electricity,
        inflow_start_node,
        inflow_end_node,
    )
    inflow_edge.unidirectional = true;
    inflow_edge.has_capacity = true;
    inflow_edge.constraints =
        get(charge_edge_data, :constraints, [MustRunConstraint()])

    hydrostor.discharge_edge = discharge_edge
    hydrostor.charge_edge = inflow_edge

    spill_edge_key = :spill_edge
    spill_edge_data = process_data(data[:edges][spill_edge_key])
    spill_start_node = hydrostor
    spill_end_node = find_node(system.locations, Symbol(spill_edge_data[:end_vertex]))
    spill_edge = Edge(
        Symbol(id, "_", spill_edge_key),
        spill_edge_data,
        system.time_data[:Electricity],
        Electricity,
        spill_start_node,
        spill_end_node,
    )
    spill_edge.unidirectional = true;
    spill_edge.has_capacity = false;
    spill_edge.constraints = get(discharge_edge_data, :constraints, [HydroMinFlowConstraint()])

    hydrostor.balance_data = Dict(
        :storage => Dict(
            discharge_edge.id => 1.0,
            inflow_edge.id => 1.0,
            spill_edge.id => 1.0
        )
    )

    return HydroRes(id,hydrostor,discharge_edge,inflow_edge,spill_edge)
end
