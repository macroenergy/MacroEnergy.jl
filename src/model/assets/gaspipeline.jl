struct GasPipeline{T} <: AbstractAsset
    id::AssetId
    gas_storage::AbstractStorage{T}
    discharge_edge::Edge{T}
    charge_edge::Edge{T}
    charge_elec_edge::Edge{Electricity}
end

GasPipeline(id::AssetId,gas_storage::AbstractStorage{T},discharge_edge::Edge{T},charge_edge::Edge{T},discharge_elec_edge::Edge{Electricity},
charge_elec_edge::Edge{Electricity}) where T<:Commodity =
    GasPipeline{T}(id,gas_storage,discharge_edge,charge_edge,discharge_elec_edge,charge_elec_edge)

function make(::Type{GasPipeline}, data::AbstractDict{Symbol,Any}, system::System)

    id = AssetId(data[:id])
    
    pipeline_key = :pipeline
    pipeline_data = process_data(data[pipeline_key])
    T = commodity_types()[Symbol(pipeline_data[:commodity])]
    # check if the storage is a long duration storage
    long_duration = get(pipeline_data, :long_durationgas_storage, false)
    StorageType = long_duration ? LongDurationStorage : Storage

    # Create the storage component of the pipeline 
    # Storage capacity is fixed equal to the discharge capacity by setting max_duration=min_duration=1.0
    # Charge capacity is fixed equal to the discharge capacity by setting charge_discharge_ratio=1.0
    gas_storage = StorageType{T}(;
        id = Symbol(id, "_", pipeline_key, "_storage"),
        timedata = system.time_data[Symbol(T)],
        can_expand = get(pipeline_data, :can_expand, false),
        capacity_size = get(pipeline_data, :capacity_size, 1.0),
        can_retire = get(pipeline_data, :can_retire, false),
        charge_edge =  nothing,
        charge_discharge_ratio = 1.0,
        discharge_edge =  nothing,
        existing_capacity = get(pipeline_data, :existing_capacity, 0.0),
        fixed_om_cost = 0.0,
        investment_cost = 0.0,
        loss_fraction = get(pipeline_data, :loss_fraction, 0.0),
        max_capacity = Inf,
        max_duration = 1.0,
        max_storage_level = get(pipeline_data, :max_storage_level, 1.0),
        min_capacity = 0.0,
        min_duration = 1.0,
        min_outflow_fraction = 0.0,
        min_storage_level = get(pipeline_data, :min_storage_level, 0.0),
        spillage_edge = nothing,
    )
    gas_storage.constraints = [BalanceConstraint(),
                            StorageMinDurationConstraint(),
                            StorageMaxDurationConstraint(),
                            StorageChargeDischargeRatioConstraint(),
                            MaxStorageLevelConstraint(),
                            MinStorageLevelConstraint()]
    if long_duration
        push!(gas_storage.constraints, LongDurationStorageImplicitMinMaxConstraint())
    end

    # Create the charge edge component of the pipeline
    charge_start_node = find_node(system.locations, Symbol(pipeline_data[:start_vertex]))
    charge_end_node = gas_storage
    gas_storage_charge =  Edge(
        Symbol(id, "_", pipeline_key, "_charge"),
        Dict{Symbol,Any}(
            :has_capacity => true,
            :undirectonal => true,
            :constraints => [CapacityConstraint()],
            :existing_capacity => get(pipeline_data, :existing_capacity, 0.0),
            :can_expand => get(pipeline_data, :can_expand, false),
            :can_retire => get(pipeline_data, :can_retire, false),
            :capacity_size => get(pipeline_data, :capacity_size, 1.0),
            :investment_cost => 0.0,
            :fixed_om_cost => 0.0,
        ),
        system.time_data[Symbol(T)],
        T,
        charge_start_node,
        charge_end_node,
    )

    # Create the discharge edge component of the pipeline
    discharge_start_node = gas_storage
    discharge_end_node = find_node(system.locations, Symbol(pipeline_data[:end_vertex]))
    gas_storage_discharge = Edge(
        Symbol(id, "_", pipeline_key, "_discharge"),
        Dict{Symbol,Any}(
            :can_expand => get(pipeline_data, :can_expand, false),
            :can_retire => get(pipeline_data, :can_retire, false),
            :capacity_size => get(data, :capacity_size, 1.0),
            :distance => get(pipeline_data, :distance, 0.0),
            :existing_capacity => get(pipeline_data, :existing_capacity, 0.0),
            :fixed_om_cost => get(pipeline_data, :fixed_om_cost, 0.0),
            :has_capacity => get(pipeline_data, :has_capacity, false),
            :integer_decisions => get(pipeline_data, :integer_decisions, false),
            :investment_cost => get(pipeline_data, :investment_cost, 0.0),
            :max_capacity => get(pipeline_data, :max_capacity, Inf),
            :min_capacity => get(pipeline_data, :min_capacity, 0.0),
            :unidirectional => true,
            :variable_om_cost => get(pipeline_data, :variable_om_cost, 0.0),
        ),
        system.time_data[Symbol(T)],
        T,
        discharge_start_node,
        discharge_end_node,
    )
    gas_storage_discharge.constraints = get(pipeline_data, :constraints,[CapacityConstraint()])
    gas_storage_discharge.unidirectional = true;

    gas_storage.discharge_edge = gas_storage_discharge
    gas_storage.charge_edge = gas_storage_charge

    charge_elec_edge_key = :charge_elec_edge

    elec_start_node = find_node(system.locations, Symbol(pipeline_data[:start_vertex]))
    elec_end_node = gas_storage
    charge_elec_edge = Edge(
        Symbol(id, "_", pipeline_key, "_charge_elec"),
        Dict{Symbol,Any}(
            :undirectional => true,
            :has_capacity => false,
        ),
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    charge_elec_edge.constraints = Vector{AbstractTypeConstraint}()

    gas_storage.balance_data = Dict(
        :storage => Dict(
            gas_storage_discharge.id => 1.0,
            gas_storage_charge.id => 1.0,
        ),
        :charge_electricity_consumption => Dict(
            #This is multiplied by -1 because they are both edges that enters storage, 
            #so we need to get one of them on the right side of the equality balance constraint    
            charge_elec_edge.id => -1.0,
            gas_storage_charge.id => get(pipeline_data, :electricity_consumption, 0.0), 
        ),
    )

    return GasPipeline(
        id,
        gas_storage,
        gas_storage_discharge,
        gas_storage_charge,
        charge_elec_edge
    )


end