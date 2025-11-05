struct HydroRes <: AbstractAsset
    id::AssetId
    hydrostor::AbstractStorage{<:Electricity}
    discharge_edge::Edge{<:Electricity}
    inflow_edge::Edge{<:Electricity}
    spill_edge::Edge{<:Electricity}
end

function default_data(t::Type{HydroRes}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{HydroRes}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :storage => @storage_data(
            :commodity => Electricity,
            :charge_discharge_ratio => 1.0,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
                :StorageChargeDischargeRatioConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :discharge_edge => @edge_data(
                :commodity => "Electricity",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true
                ),
            ),
            :inflow_edge => @edge_data(
                :commodity => "Electricity",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :MustRunConstraint => true,
                ),
            ),
            :spill_edge => @edge_data(
                :commodity => "Electricity",
            ),
        ),
    )
end

function simple_default_data(::Type{HydroRes}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :storage_can_expand => true,
        :storage_can_retire => true,
        :discharge_can_expand => true,
        :discharge_can_retire => true,
        :inflow_can_expand => true,
        :inflow_can_retire => true,
        :hydro_source => missing,
        :storage_long_duration => false,
        :storage_existing_capacity => 0.0,
        :discharge_existing_capacity => 0.0,
        :inflow_existing_capacity => 0.0,
        :storage_charge_discharge_ratio => 1.0,
        :discharge_investment_cost => 0.0,
        :discharge_fixed_om_cost => 0.0,
        :discharge_variable_om_cost => 0.0,
        :inflow_investment_cost => 0.0,
        :inflow_fixed_om_cost => 0.0,
        :inflow_variable_om_comst => 0.0,
        :discharge_efficiency => 1.0,
        :inflow_efficiency => 1.0,
    )
end

function make(asset_type::Type{HydroRes}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    @setup_data(asset_type, data, id)

    ## Storage component of the hydro reservoir
    storage_key = :storage
    @process_data(
        storage_data,
        data[storage_key],
        [
            (data[storage_key], key),
            (data[storage_key], Symbol("storage_", key)),
            (data, Symbol("storage_", key)),
        ]
    )
    # check if the storage is a long duration storage
    long_duration = get(storage_data, :long_duration, false)
    StorageType = long_duration ? LongDurationStorage : Storage
    # create the storage component of the hydro reservoir
    hydrostor = StorageType(
        Symbol(id, "_", storage_key),
        storage_data,
        system.time_data[:Electricity],
        Electricity,
    )
    if long_duration
        lds_constraints = [LongDurationStorageImplicitMinMaxConstraint()]
        for c in lds_constraints
            if !(c in hydrostor.constraints)
                push!(hydrostor.constraints, c)
            end
        end
    end

    discharge_edge_key = :discharge_edge
    @process_data(
        discharge_edge_data,
        data[:edges][discharge_edge_key],
        [
            (data[:edges][discharge_edge_key], key),
            (data[:edges][discharge_edge_key], Symbol("discharge_", key)),
            (data, Symbol("discharge_", key)),
        ]
    )
    discharge_start_node = hydrostor
    @end_vertex(
        discharge_end_node,
        discharge_edge_data,
        Electricity,
        [(discharge_edge_data, :end_vertex), (data, :location)],
    )
    discharge_edge = Edge(
        Symbol(id, "_", discharge_edge_key),
        discharge_edge_data,
        system.time_data[:Electricity],
        Electricity,
        discharge_start_node,
        discharge_end_node,
    )

    inflow_edge_key = :inflow_edge
    @process_data(
        inflow_edge_data,
        data[:edges][inflow_edge_key],
        [
            (data[:edges][inflow_edge_key], key),
            (data[:edges][inflow_edge_key], Symbol("inflow_", key)),
            (data, Symbol("inflow_", key)),
        ]
    )
    @start_vertex(
        inflow_start_node,
        inflow_edge_data,
        Electricity,
        [(inflow_edge_data, :start_vertex), (data, :hydro_source), (data, :location),],
    )
    inflow_end_node = hydrostor
    inflow_edge = Edge(
        Symbol(id, "_", inflow_edge_key),
        inflow_edge_data,
        system.time_data[:Electricity],
        Electricity,
        inflow_start_node,
        inflow_end_node,
    )
    inflow_edge.can_retire = discharge_edge.can_retire;
    inflow_edge.can_expand = discharge_edge.can_expand;
    inflow_edge.existing_capacity = discharge_edge.existing_capacity;
    inflow_edge.capacity_size = discharge_edge.capacity_size;

    spill_edge_key = :spill_edge
    @process_data(
        spill_edge_data,
        data[:edges][spill_edge_key],
        [
            (data[:edges][spill_edge_key], key),
            (data[:edges][spill_edge_key], Symbol("spill_", key)),
            (data, Symbol("spill_", key)),
        ]
    )
    spill_start_node = hydrostor
    @end_vertex(
        spill_end_node,
        spill_edge_data,
        Electricity,
        [(spill_edge_data, :end_vertex), (data, :hydro_source), (data, :location),],
    )
    spill_edge = Edge(
        Symbol(id, "_", spill_edge_key),
        spill_edge_data,
        system.time_data[:Electricity],
        Electricity,
        spill_start_node,
        spill_end_node,
    )

    hydrostor.discharge_edge = discharge_edge
    hydrostor.charge_edge = inflow_edge
    hydrostor.spillage_edge = spill_edge

    discharge_efficiency = get_from([
            (discharge_edge_data, :discharge_efficiency),
            (discharge_edge_data, :efficiency)
        ], 1.0)
    inflow_efficiency = get_from([
            (inflow_edge_data, :inflow_efficiency),
            (inflow_edge_data, :efficiency)
        ], 1.0)

    hydrostor.balance_data = Dict(
        :storage => Dict(
            discharge_edge.id => 1 / discharge_efficiency,
            inflow_edge.id => inflow_efficiency,
            spill_edge.id => 1.0
        )
    )

    return HydroRes(id,hydrostor,discharge_edge,inflow_edge,spill_edge)
end
