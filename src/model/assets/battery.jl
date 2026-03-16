struct Battery <: AbstractAsset
    id::AssetId
    battery_storage::AbstractStorage{<:Electricity}
    discharge_edge::Edge{<:Electricity}
    charge_edge::Edge{<:Electricity}
end

function default_data(t::Type{Battery}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{Battery}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :storage => @storage_data(
            :commodity => "Electricity",
            :can_expand => true,
            :can_retire => true,
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true,
                :StorageCapacityConstraint => true,
                :StorageSymmetricCapacityConstraint => true,
            )
        ),
        :edges => Dict{Symbol,Any}(
            :charge_edge => @edge_data(
                :efficiency => 1.0,
                :commodity => "Electricity",
            ),
            :discharge_edge => @edge_data(
                :efficiency => 1.0,
                :commodity => "Electricity",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                    :StorageDischargeLimitConstraint => true,
                    :StorageChargeLimitConstraint => true
                )
            )
        )
    )
end

function simple_default_data(::Type{Battery}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :storage_can_expand => true,
        :storage_can_retire => true,
        :discharge_can_expand => true,
        :discharge_can_retire => true,
        :charge_can_expand => true,
        :charge_can_retire => true,
        :storage_existing_capacity => 0.0,
        :discharge_existing_capacity => 0.0,
        :charge_existing_capacity => 0.0,
        :storage_investment_cost => 0.0,
        :storage_fixed_om_cost => 0.0,
        :storage_max_duration => 100.0,
        :storage_min_duration => 0.0,
        :discharge_investment_cost => 0.0,
        :discharge_fixed_om_cost => 0.0,
        :discharge_variable_om_cost => 0.0,
        :charge_investment_cost => 0.0,
        :charge_fixed_om_cost => 0.0,
        :charge_variable_om_cost => 0.0,
        :discharge_efficiency => 1.0,
        :charge_efficiency => 1.0,
    )
end

"""
    make(::Type{Battery}, data::AbstractDict{Symbol, Any}, system::System) -> Battery

    Necessary data fields:
     - storage: Dict{Symbol, Any}
        - id: String
        - commodity: String
        - can_retire: Bool
        - can_expand: Bool
        - existing_capacity: Float64
        - investment_cost: Float64
        - fixed_om_cost: Float64
        - loss_fraction: Float64
        - min_duration: Float64
        - max_duration: Float64
        - min_storage_level: Float64
        - min_capacity: Float64
        - max_capacity: Float64
        - constraints: Vector{AbstractTypeConstraint}
     - edges: Dict{Symbol, Any}
        - charge_edge: Dict{Symbol, Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_capacity: Bool
            - efficiency: Float64
        - discharge_edge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_capacity: Bool
            - can_retire: Bool
            - can_expand: Bool
            - efficiency
            - constraints: Vector{AbstractTypeConstraint}
"""
function make(asset_type::Type{Battery}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    ## Storage component of the battery
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
    commodity_symbol = Symbol(storage_data[:commodity])
    commodity = commodity_types()[commodity_symbol]

    # Check if the storage is a long duration storage
    long_duration = get(storage_data, :long_duration, false)
    StorageType = long_duration ? LongDurationStorage : Storage
    
    # Create the storage component of the battery
    battery_storage = StorageType(
        Symbol(id, "_", storage_key),
        storage_data,
        system.time_data[commodity_symbol],
        commodity,
        location
    )

    # If storage is long duration, add the implicit min-max constraint
    if long_duration
        lds_constraints = [LongDurationStorageImplicitMinMaxConstraint()]
        for c in lds_constraints
            if !(c in battery_storage.constraints)
                push!(battery_storage.constraints, c)
            end
        end
    end

    ## Charge data of the battery
    charge_edge_key = :charge_edge
    @process_data(
        charge_edge_data,
        data[:edges][charge_edge_key],
        [
            (data[:edges][charge_edge_key], key),
            (data[:edges][charge_edge_key], Symbol("charge_", key)),
            (data, Symbol("charge_", key)),
        ]
    )
    # Use charge_integer_decisions if set, otherwise fall back to global integer_decisions if set
    charge_integer = get_from([
        (data, :charge_integer_decisions),
        (data, :integer_decisions),
    ], missing, false)
    if !ismissing(charge_integer)
        charge_edge_data[:integer_decisions] = charge_integer
    end
    @start_vertex(
        charge_start_node,
        charge_edge_data,
        commodity,
        [(charge_edge_data, :start_vertex), (data, :location)],
    )
    charge_end_node = battery_storage
    battery_charge = Edge(
        Symbol(id, "_", charge_edge_key),
        charge_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        charge_start_node,
        charge_end_node,
    )

    ## Discharge output of the battery
    discharge_edge_key = :discharge_edge
    @process_data(
        discharge_edge_data, 
        data[:edges][discharge_edge_key], 
        [
            (data[:edges][discharge_edge_key], key),
            (data[:edges][discharge_edge_key], Symbol("discharge_", key)),
            (data, Symbol("discharge_", key)),
        ])
    # Use discharge_integer_decisions if set, otherwise fall back to global integer_decisions if set
    discharge_integer = get_from([
        (data, :discharge_integer_decisions),
        (data, :integer_decisions),
    ], missing, false)
    if !ismissing(discharge_integer)
        discharge_edge_data[:integer_decisions] = discharge_integer
    end
    discharge_start_node = battery_storage
    @end_vertex(
        discharge_end_node,
        discharge_edge_data,
        commodity,
        [(discharge_edge_data, :end_vertex), (data, :location)],
    )
    battery_discharge = Edge(
        Symbol(id, "_", discharge_edge_key),
        discharge_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        discharge_start_node,
        discharge_end_node,
    )

    battery_storage.discharge_edge = battery_discharge
    battery_storage.charge_edge = battery_charge
    
    discharge_efficiency = get_from([
            (discharge_edge_data, :discharge_efficiency),
            (discharge_edge_data, :efficiency)
        ], 1.0)
    charge_efficiency = get_from([
            (charge_edge_data, :charge_efficiency),
            (charge_edge_data, :efficiency)
        ], 1.0)
    battery_storage.balance_data = Dict(
        :storage => Dict(
            battery_discharge.id => 1 / discharge_efficiency,
            battery_charge.id => charge_efficiency,
        ),
    )

    return Battery(id, battery_storage, battery_discharge, battery_charge)
end
