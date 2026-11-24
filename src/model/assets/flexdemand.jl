# GenX's flexible demand: a storage whose level is the deferred demand (positive when deferred, negative when served
# in advance). The defer edge (storage to node) carries the deferred demand and the flexible capacity; the serve edge
# (node to storage) carries the demand served later or earlier.
struct FlexDemand{T} <: AbstractAsset
    id::AssetId
    tags::AssetTags
    storage::Storage{<:T}
    defer_edge::Edge{<:T}
    serve_edge::Edge{<:T}
end

FlexDemand(id::AssetId, tags::AssetTags, storage::Storage{T}, defer_edge::Edge{T}, serve_edge::Edge{T}) where {T<:Commodity} =
    FlexDemand{T}(id, tags, storage, defer_edge, serve_edge)

const FLEXDEMAND_PARAMETERS = (:flexible_demand_energy_eff, :max_flexible_demand_delay, :max_flexible_demand_advance)

function default_data(t::Type{FlexDemand}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{FlexDemand}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :flexible_demand_energy_eff => missing,
        :max_flexible_demand_delay => missing,
        :max_flexible_demand_advance => missing,
        :storage => @storage_data(
            :commodity => missing,
            :can_expand => false,
            :can_retire => false,
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :defer_edge => @edge_data(
                :commodity => missing,
                :has_capacity => true,
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                ),
            ),
            :serve_edge => @edge_data(
                :commodity => missing,
            ),
        ),
    )
end

function simple_default_data(::Type{FlexDemand}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :storage_commodity => missing,
        :flexible_demand_energy_eff => missing,
        :max_flexible_demand_delay => missing,
        :max_flexible_demand_advance => missing,
        :defer_can_expand => false,
        :defer_can_retire => false,
        :defer_existing_capacity => 0.0,
        :defer_investment_cost => 0.0,
        :defer_fixed_om_cost => 0.0,
        :defer_variable_om_cost => 0.0,
        :serve_variable_om_cost => 0.0,
    )
end

function set_commodity!(::Type{FlexDemand}, commodity::Type{<:Commodity}, data::AbstractDict{Symbol,Any})
    if haskey(data, :storage_commodity)
        data[:storage_commodity] = string(commodity)
    end
    if haskey(data, :storage) && haskey(data[:storage], :commodity)
        data[:storage][:commodity] = string(commodity)
    end
    for key in (:defer_edge, :serve_edge)
        if haskey(data, :edges) && haskey(data[:edges], key) && haskey(data[:edges][key], :commodity)
            data[:edges][key][:commodity] = string(commodity)
        end
    end
    return nothing
end

function make(asset_type::Type{FlexDemand}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    # GenX has no defaults for these three parameters.
    for key in FLEXDEMAND_PARAMETERS
        ismissing(get(data, key, missing)) && throw(ArgumentError("FlexDemand $id: $key is required."))
    end
    efficiency = Float64(data[:flexible_demand_energy_eff])
    delay_hours = data[:max_flexible_demand_delay]
    advance_hours = data[:max_flexible_demand_advance]
    efficiency > 0 ||
        throw(ArgumentError("FlexDemand $id: flexible_demand_energy_eff must be > 0, got $efficiency."))
    (delay_hours >= 0 && advance_hours >= 0) || throw(ArgumentError(
        "FlexDemand $id: max_flexible_demand_delay and max_flexible_demand_advance must be >= 0."))

    ## Storage component: the deferred demand
    storage_key = :storage
    @process_data(
        storage_data,
        data[storage_key],
        [
            (data[storage_key], key),
            (data[storage_key], Symbol("storage_", key)),
            (data, Symbol("storage_", key)),
        ],
    )
    haskey(storage_data, :commodity) ||
        throw(ArgumentError("FlexDemand $id: the storage has no commodity; set `storage_commodity`."))
    commodity_symbol = Symbol(storage_data[:commodity])
    commodity = get(commodity_types(), commodity_symbol, nothing)
    isnothing(commodity) &&
        throw(ArgumentError("FlexDemand $id: commodity $commodity_symbol is not a defined commodity."))
    get(storage_data, :long_duration, false) &&
        throw(ArgumentError("FlexDemand $id: long_duration is not supported."))

    storage = Storage(Symbol(id, "_", storage_key), storage_data, system.time_data[commodity_symbol], commodity, location)
    any(c -> c isa BalanceConstraint, storage.constraints) ||
        throw(ArgumentError("FlexDemand $id: the storage needs its BalanceConstraint."))
    for c in storage.constraints
        c isa BalanceConstraint || throw(ArgumentError("FlexDemand $id: storage constraint $(typeof(c)) is not " *
            "supported; the asset adds its own FlexDemandConstraint."))
    end
    # GenX has no energy capacity and no decay on the deferred demand.
    (can_expand(storage) || existing_capacity(storage) != 0) && throw(ArgumentError("FlexDemand $id: the storage " *
        "has no energy capacity; leave can_expand false and existing_capacity 0."))
    any(!iszero, loss_fraction(storage)) &&
        throw(ArgumentError("FlexDemand $id: a storage loss_fraction is not supported."))

    ## Defer edge, from the storage to the node: deferred demand, bounded by availability x flexible capacity
    defer_edge_key = :defer_edge
    @process_data(
        defer_edge_data,
        data[:edges][defer_edge_key],
        [
            (data[:edges][defer_edge_key], key),
            (data[:edges][defer_edge_key], Symbol("defer_", key)),
            (data, Symbol("defer_", key)),
        ],
    )
    @end_vertex(
        defer_end_node,
        defer_edge_data,
        commodity,
        [(defer_edge_data, :end_vertex), (data, :location)],
    )
    defer_edge = Edge(
        Symbol(id, "_", defer_edge_key),
        defer_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        storage,
        defer_end_node,
    )
    has_capacity(defer_edge) ||
        throw(ArgumentError("FlexDemand $id: the defer_edge needs has_capacity = true; it holds the flexible capacity."))
    any(c -> c isa CapacityConstraint, defer_edge.constraints) ||
        throw(ArgumentError("FlexDemand $id: the defer_edge needs its CapacityConstraint."))

    ## Serve edge, from the node to the storage: deferred or advanced demand that is served
    serve_edge_key = :serve_edge
    @process_data(
        serve_edge_data,
        data[:edges][serve_edge_key],
        [
            (data[:edges][serve_edge_key], key),
            (data[:edges][serve_edge_key], Symbol("serve_", key)),
            (data, Symbol("serve_", key)),
        ],
    )
    @start_vertex(
        serve_start_node,
        serve_edge_data,
        commodity,
        [(serve_edge_data, :start_vertex), (data, :location)],
    )
    serve_edge = Edge(
        Symbol(id, "_", serve_edge_key),
        serve_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        serve_start_node,
        storage,
    )
    serve_start_node === defer_end_node ||
        throw(ArgumentError("FlexDemand $id: the defer_edge and serve_edge must connect to the same node."))

    # level(t) = level(t-1) + defer(t) - efficiency * serve(t). Macro negates the coefficient of an edge leaving the
    # storage, so the outgoing defer edge gets -1 and the incoming serve edge -efficiency.
    storage.balance_data = Dict(:storage => Dict(defer_edge.id => -1.0, serve_edge.id => -efficiency))
    storage.charge_edge = defer_edge
    storage.discharge_edge = serve_edge

    hpt = hours_per_timestep(storage)
    push!(storage.constraints, FlexDemandConstraint(
        efficiency = efficiency,
        max_delay = floor(Int, delay_hours / hpt),
        max_advance = floor(Int, advance_hours / hpt),
    ))

    return FlexDemand(id, asset_tags(data), storage, defer_edge, serve_edge)
end

function operation_model!(a::FlexDemand, model::Model)
    invoke(operation_model!, Tuple{AbstractAsset,Model}, a, model)
    # The level is free, as in GenX: demand served in advance makes it negative. Storage creates it with lower bound 0.
    delete_lower_bound.(storage_level(a.storage))
    return nothing
end
