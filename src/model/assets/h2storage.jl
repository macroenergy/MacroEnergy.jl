struct H2Storage <: AbstractAsset
    id::AssetId
    h2storage_transform::Storage{Hydrogen}
    compressor_transform::Transformation
    discharge_edge::Edge{Hydrogen}
    charge_edge::Edge{Hydrogen}
    compressor_elec_edge::Edge{Electricity}
    compressor_h2_edge::Edge{Hydrogen}
end

function make(::Type{H2Storage}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    h2storage_key = :storage
    storage_data = process_data(data[h2storage_key])
    h2storage = Storage(
        Symbol(id, "_", h2storage_key),
        storage_data,
        system.time_data[:Hydrogen],
        Hydrogen,
    )
    h2storage.constraints = get(
        storage_data,
        :constraints,
        [BalanceConstraint(), StorageCapacityConstraint(), MinStorageLevelConstraint()],
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
    compressor_elec_edge.unidirectional =
        get(compressor_elec_edge_data, :unidirectional, true)

    compressor_h2_edge_key = :compressor_h2_edge
    compressor_h2_edge_data = process_data(data[:edges][compressor_h2_edge_key])
    h2_start_node =
        find_node(system.locations, Symbol(compressor_h2_edge_data[:start_vertex]))
    h2_end_node = compressor_transform
    compressor_h2_edge = Edge(
        Symbol(id, "_", compressor_h2_edge_key),
        compressor_h2_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_start_node,
        h2_end_node,
    )
    compressor_h2_edge.unidirectional = get(compressor_h2_edge_data, :unidirectional, true)

    charge_edge_key = :charge_edge
    charge_edge_data = process_data(data[:edges][charge_edge_key])
    charge_start_node = compressor_transform
    charge_end_node = h2storage
    h2storage_charge = Edge(
        Symbol(id, "_", charge_edge_key),
        charge_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        charge_start_node,
        charge_end_node,
    )
    h2storage_charge.unidirectional = get(charge_edge_data, :unidirectional, true)
    h2storage_charge.constraints =
        get(charge_edge_data, :constraints, [CapacityConstraint()])

    discharge_edge_key = :discharge_edge
    discharge_edge_data = process_data(data[:edges][discharge_edge_key])
    discharge_start_node = h2storage
    discharge_end_node =
        find_node(system.locations, Symbol(discharge_edge_data[:end_vertex]))
    h2storage_discharge = Edge(
        Symbol(id, "_", discharge_edge_key),
        discharge_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        discharge_start_node,
        discharge_end_node,
    )
    h2storage_discharge.constraints = get(
        discharge_edge_data,
        :constraints,
        [CapacityConstraint(), RampingLimitConstraint()],
    )
    h2storage_discharge.unidirectional = get(discharge_edge_data, :unidirectional, true)

    h2storage.discharge_edge = h2storage_discharge
    h2storage.charge_edge = h2storage_charge

    h2storage.balance_data = Dict(
        :storage => Dict(
            h2storage_discharge.id => 1 / get(discharge_edge_data, :efficiency, 1.0),
            h2storage_charge.id => get(charge_edge_data, :efficiency, 1.0),
        ),
    )

    compressor_transform.balance_data = Dict(
        :electricity => Dict(
            compressor_h2_edge.id => get(transform_data, :electricity_consumption, 0.0),
            compressor_elec_edge.id => 1.0,
            h2storage_charge.id => 0.0,
        ),
        :hydrogen => Dict(
            h2storage_charge.id => 1.0,
            compressor_h2_edge.id => 1.0,
            compressor_elec_edge.id => 0.0,
        ),
    )

    return H2Storage(
        id,
        h2storage,
        compressor_transform,
        h2storage_discharge,
        h2storage_charge,
        compressor_elec_edge,
        compressor_h2_edge,
    )
end
