# A storage connected to its node by one signed flow edge (positive = charging). With a lossless edge the balances
# read one free variable per time step, so the storage cannot charge and discharge in the same time step.
struct NetFlowStorage{T} <: AbstractAsset
    id::AssetId
    tags::AssetTags
    storage::AbstractStorage{<:T}
    flow_edge::BidirectionalEdge{<:T}
end

NetFlowStorage(id::AssetId, tags::AssetTags, storage::AbstractStorage{T}, flow_edge::BidirectionalEdge{T}) where {T<:Commodity} =
    NetFlowStorage{T}(id, tags, storage, flow_edge)

# Storage constraints that read the charge and discharge edges as two separate edges.
const NETFLOWSTORAGE_UNSUPPORTED_CONSTRAINTS = (
    MinStorageOutflowConstraint,
    StorageChargeDischargeRatioConstraint,
    StorageSymmetricCapacityConstraint,
)

function default_data(t::Type{NetFlowStorage}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{NetFlowStorage}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :storage => @storage_data(
            :commodity => missing,
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true,
                :StorageCapacityConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :flow_edge => @edge_data(
                :commodity => missing,
                :unidirectional => false,
                :has_capacity => false,
            ),
        ),
    )
end

function simple_default_data(::Type{NetFlowStorage}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :storage_commodity => missing,
        :storage_can_expand => true,
        :storage_can_retire => true,
        :storage_existing_capacity => 0.0,
        :storage_investment_cost => 0.0,
        :storage_fixed_om_cost => 0.0,
        :flow_has_capacity => false,
    )
end

function set_commodity!(::Type{NetFlowStorage}, commodity::Type{<:Commodity}, data::AbstractDict{Symbol,Any})
    if haskey(data, :storage_commodity)
        data[:storage_commodity] = string(commodity)
    end
    if haskey(data, :storage) && haskey(data[:storage], :commodity)
        data[:storage][:commodity] = string(commodity)
    end
    if haskey(data, :edges) && haskey(data[:edges], :flow_edge) && haskey(data[:edges][:flow_edge], :commodity)
        data[:edges][:flow_edge][:commodity] = string(commodity)
    end
    return nothing
end

function make(asset_type::Type{NetFlowStorage}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    ## Storage component
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
        throw(ArgumentError("NetFlowStorage $id: the storage has no commodity; set `storage_commodity`."))
    commodity_symbol = Symbol(storage_data[:commodity])
    commodity = get(commodity_types(), commodity_symbol, nothing)
    isnothing(commodity) &&
        throw(ArgumentError("NetFlowStorage $id: commodity $commodity_symbol is not a defined commodity."))

    long_duration = get(storage_data, :long_duration, false)
    StorageType = long_duration ? LongDurationStorage : Storage
    storage = StorageType(
        Symbol(id, "_", storage_key),
        storage_data,
        system.time_data[commodity_symbol],
        commodity,
        location,
    )
    for c in storage.constraints
        if any(T -> c isa T, NETFLOWSTORAGE_UNSUPPORTED_CONSTRAINTS)
            throw(ArgumentError("NetFlowStorage $id: $(typeof(c)) is not supported, because it reads " *
                "separate charge and discharge edges and this asset has one flow edge."))
        end
    end
    if long_duration && using_representative_subperiods(storage) &&
       !any(c -> c isa LongDurationStorageImplicitMinMaxConstraint, storage.constraints)
        push!(storage.constraints, LongDurationStorageImplicitMinMaxConstraint())
    end

    ## Flow edge, from the node (start vertex) to the storage (end vertex)
    flow_edge_key = :flow_edge
    @process_data(
        flow_edge_data,
        data[:edges][flow_edge_key],
        [
            (data[:edges][flow_edge_key], key),
            (data[:edges][flow_edge_key], Symbol("flow_", key)),
            (data, Symbol("flow_", key)),
        ],
    )
    @start_vertex(
        flow_start_node,
        flow_edge_data,
        commodity,
        [(flow_edge_data, :start_vertex), (data, :location)],
    )
    flow_edge = BidirectionalEdge(
        Symbol(id, "_", flow_edge_key),
        flow_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        flow_start_node,
        storage,
    )
    storage.balance_data = Dict(:storage => Dict(flow_edge.id => 1.0))
    # The flow edge is both the charge and the discharge edge, so constraints that read them see one signed flow.
    storage.charge_edge = flow_edge
    storage.discharge_edge = flow_edge

    # The duration constraints read the capacity of the discharge edge, so they need a capacitated flow edge.
    # Without one, Macro would skip them, so they are an error.
    if !has_capacity(flow_edge) &&
       any(c -> c isa StorageMinDurationConstraint || c isa StorageMaxDurationConstraint, storage.constraints)
        throw(ArgumentError("NetFlowStorage $id: StorageMinDurationConstraint and StorageMaxDurationConstraint " *
            "need a flow_edge with has_capacity = true."))
    end

    return NetFlowStorage(id, asset_tags(data), storage, flow_edge)
end
