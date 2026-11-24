module TestAssetNetFlowStorageBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    Battery,
    BalanceConstraint,
    BalanceData,
    BidirectionalEdge,
    Electricity,
    LongDurationStorage,
    LongDurationStorageImplicitMinMaxConstraint,
    NetFlowStorage,
    Node,
    OrderedDict,
    SupplySegment,
    TimeData,
    asset_tags,
    balance_data,
    capacity,
    commodity_types,
    end_vertex,
    flow,
    flow_neg,
    flow_pos,
    get_balance,
    id,
    loss_fraction,
    make,
    start_vertex,
    storage_initial,
    storage_level,
    storage_net_inflow

# Two representative 3-hour subperiods standing for three modeled ones (subperiod 3 is represented by 1).
function tdr_timedata(::Type{T}) where {T}
    return TimeData{T}(; time_interval = 1:6, hours_per_timestep = 1, period_index = 1,
        subperiods = [1:3, 4:6], subperiod_indices = [1, 2], subperiod_weights = Dict(1 => 2.0, 2 => 1.0),
        subperiod_map = Dict(1 => 1, 2 => 2, 3 => 1), total_hours_modeled = 9)
end

# One node with, by default, cheap supply in the first hour of each subperiod and a flat demand of 5:
# the storage buys 10 in the first hour and gives back 5 in each of the next two.
function pool_system(product::Symbol; tdr::Bool = false, demand = nothing, price = nothing)
    P = commodity_types()[product]
    system = make_test_system(DataType[P])
    tdr && (system.time_data[product] = tdr_timedata(P))
    td = system.time_data[product]
    n = length(td.time_interval)
    node = Node{P}(; id = :pool, timedata = td, constraints = [BalanceConstraint()],
        balance_data = Dict(:demand => BalanceData()), demand = something(demand, fill(5.0, n)),
        supply = OrderedDict(:grid => SupplySegment(price = something(price, repeat([1.0, 100.0, 100.0], n ÷ 3)),
                                                    min = [0.0], max = [Inf])))
    push_locations!(system, node)
    return system
end

function make_case(product::Symbol; storage = Dict{Symbol,Any}(), edge = Dict{Symbol,Any}(), tags = nothing,
                   tdr::Bool = false, demand = nothing, price = nothing)
    system = pool_system(product; tdr, demand, price)
    data = Dict{Symbol,Any}(
        :id => :store,
        :storage => merge(Dict{Symbol,Any}(:commodity => string(product), :can_expand => true,
                                           :investment_cost => 0.1, :existing_capacity => 0.0), storage),
        :edges => Dict{Symbol,Any}(:flow_edge => merge(Dict{Symbol,Any}(:commodity => string(product),
                                                                         :start_vertex => :pool), edge)),
    )
    tags === nothing || (data[:tags] = tags)
    asset = make(NetFlowStorage, data, system)
    push!(system.assets, asset)
    return system, asset
end

has_implicit(storage) = any(c -> c isa LongDurationStorageImplicitMinMaxConstraint, storage.constraints)

# What the flow edge delivers to the storage at t: on a lossy edge, (1 - loss) of flow_pos minus flow_neg.
delivered(e, t) = isempty(flow_pos(e)) ? value(flow(e, t)) :
    (1 - loss_fraction(e, t)) * value(flow_pos(e, t)) - value(flow_neg(e, t))

function test_one_signed_flow()
    for product in (:Methanol, :Ammonia, :CO2Captured)
        @testset "$product: one signed flow, no same-hour charge and discharge" begin
            system, asset = make_case(product)
            @test asset isa NetFlowStorage && asset_tags(asset) === nothing
            @test asset.flow_edge isa BidirectionalEdge
            @test id(start_vertex(asset.flow_edge)) == :pool && end_vertex(asset.flow_edge) === asset.storage
            @test asset.storage.charge_edge === asset.flow_edge && asset.storage.discharge_edge === asset.flow_edge
            build_test_model(system)
            @test isempty(flow_pos(asset.flow_edge)) && isempty(flow_neg(asset.flow_edge))
            @test value.(flow(asset.flow_edge)) ≈ [10.0, -5.0, -5.0] atol = 1e-6
            @test value.(storage_level(asset.storage)) ≈ [10.0, 5.0, 0.0] atol = 1e-6
            @test value(capacity(asset.storage)) ≈ 10.0 atol = 1e-6
        end
    end
end

function test_simple_input_and_tags()
    @testset "simple-style input gives the same storage" begin
        system = pool_system(:Methanol)
        asset = make(NetFlowStorage, Dict{Symbol,Any}(
            :id => :store, :storage_commodity => "Methanol", :storage_can_expand => true,
            :storage_investment_cost => 0.1, :storage_existing_capacity => 0.0, :flow_start_vertex => :pool,
        ), system)
        push!(system.assets, asset)
        build_test_model(system)
        @test value.(flow(asset.flow_edge)) ≈ [10.0, -5.0, -5.0] atol = 1e-6
    end
    @testset "tags pass through" begin
        _, asset = make_case(:Methanol; tags = ["tagged"])
        @test asset_tags(asset) == [:tagged]
    end
end

function test_long_duration()
    @testset "long_duration, every subperiod representative: no implicit min-max" begin
        system, asset = make_case(:CO2Captured; storage = Dict{Symbol,Any}(:long_duration => true))
        @test asset.storage isa LongDurationStorage && !has_implicit(asset.storage)
        build_test_model(system)
        @test value.(flow(asset.flow_edge)) ≈ [10.0, -5.0, -5.0] atol = 1e-6
    end
    @testset "long_duration with representative subperiods: implicit min-max added" begin
        _, asset = make_case(:CO2Captured; storage = Dict{Symbol,Any}(:long_duration => true), tdr = true)
        @test asset.storage isa LongDurationStorage && has_implicit(asset.storage)
    end
    # Subperiods 1 and 3 (both represented by 1) deliver 1 in their first hour and then charge cheaply; subperiod 2
    # delivers 6. With η = 1 - edge loss, subperiod 3 starts 3/η below subperiod 1, so only the implicit min-max
    # constraint keeps its first hour from going below 0: the capacity is 7/η with the constraint and 6/η without it.
    @testset "the implicit min-max bounds the level in a non-representative subperiod (edge loss $loss)" for loss in (0.0, 0.1)
        η = 1 - loss
        for with_implicit in (true, false)
            system, asset = make_case(:Methanol; storage = Dict{Symbol,Any}(:long_duration => true), tdr = true,
                edge = Dict{Symbol,Any}(:loss_fraction => loss),
                demand = [1.0, 0.0, 0.0, 2.0, 2.0, 2.0], price = [100.0, 1.0, 1.0, 100.0, 100.0, 100.0])
            with_implicit ||
                filter!(c -> !(c isa LongDurationStorageImplicitMinMaxConstraint), asset.storage.constraints)
            build_test_model(system)
            @test value(capacity(asset.storage)) ≈ (with_implicit ? 7.0 : 6.0) / η atol = 1e-6
            # Level of subperiod 3 after its first hour.
            @test value(storage_initial(asset.storage, 3)) + delivered(asset.flow_edge, 1) ≈
                  (with_implicit ? 0.0 : -1.0) / η atol = 1e-6
        end
    end
end

# A loss of 0.1 applies in both directions: the storage keeps 0.9 of what it takes and the node gets 0.9 of what the
# storage gives back. Delivering 5 per hour takes 50/9 from the storage, and filling it takes 1000/81 from the node.
function test_lossy_flow_edge()
    @testset "a lossy flow_edge loses in both directions" begin
        system, asset = make_case(:Methanol; edge = Dict{Symbol,Any}(:loss_fraction => 0.1))
        build_test_model(system)
        e = asset.flow_edge
        @test value.(flow_pos(e)) ≈ [1000 / 81, 0.0, 0.0] atol = 1e-6
        @test value.(flow_neg(e)) ≈ [0.0, 50 / 9, 50 / 9] atol = 1e-6
        @test value.(flow(e)) ≈ value.(flow_pos(e)) .- value.(flow_neg(e)) atol = 1e-6
        @test value.(storage_level(asset.storage)) ≈ [100 / 9, 50 / 9, 0.0] atol = 1e-6
        @test value(capacity(asset.storage)) ≈ 100 / 9 atol = 1e-6
    end
end

# The implicit min-max constraint must count the flow edge as the storage balance does, with or without a loss.
function test_net_inflow_matches_balance()
    for loss in (0.0, 0.1)
        @testset "storage_net_inflow has the storage balance's flow coefficients (edge loss $loss)" begin
            system, asset = make_case(:Methanol; storage = Dict{Symbol,Any}(:long_duration => true), tdr = true,
                                      edge = Dict{Symbol,Any}(:loss_fraction => loss))
            build_test_model(system)
            g, e = asset.storage, asset.flow_edge
            for t in (1, 4)
                inflow = storage_net_inflow(g, e, e, balance_data(g, :storage), t)
                balance = get_balance(g, :storage, t)
                vars = iszero(loss) ? [flow(e, t)] : [flow_pos(e, t), flow_neg(e, t)]
                @test all(v -> coefficient(inflow, v) == coefficient(balance, v) != 0, vars)
                @test coefficient(inflow, flow(e, t)) == coefficient(balance, flow(e, t))
            end
        end
    end
end

function test_variable_om_cost()
    @testset "a flow_edge variable_om_cost prices |flow|; the balances keep one signed flow" begin
        system0, _ = make_case(:Methanol)
        model0 = build_test_model(system0)
        system, asset = make_case(:Methanol; edge = Dict{Symbol,Any}(:variable_om_cost => 0.5))
        model = build_test_model(system)
        @test value.(flow(asset.flow_edge)) ≈ [10.0, -5.0, -5.0] atol = 1e-6
        @test value.(flow_pos(asset.flow_edge)) ≈ [10.0, 0.0, 0.0] atol = 1e-6
        @test value.(flow_neg(asset.flow_edge)) ≈ [0.0, 5.0, 5.0] atol = 1e-6
        @test objective_value(model) - objective_value(model0) ≈ 0.5 * 20.0 atol = 1e-6
    end
end

function test_rejected_inputs()
    two_edge_constraints = (:MinStorageOutflowConstraint, :StorageChargeDischargeRatioConstraint,
                            :StorageSymmetricCapacityConstraint)
    for name in two_edge_constraints
        @testset "$name is rejected" begin
            constraints = Dict{Symbol,Bool}(:BalanceConstraint => true, :StorageCapacityConstraint => true, name => true)
            @test_throws "$name is not supported" make_case(:CO2Captured;
                storage = Dict{Symbol,Any}(:long_duration => true, :constraints => constraints))
        end
    end
    @testset "a storage without a commodity is rejected" begin
        system = pool_system(:Methanol)
        @test_throws "has no commodity" make(NetFlowStorage, Dict{Symbol,Any}(:id => :store, :flow_start_vertex => :pool), system)
    end
end

# A thermal-storage shape: a priced power capacity on the flow edge, volume = duration x power, a standing loss.
const DURATION_STORAGE = Dict{Symbol,Any}(:min_duration => 2.0, :max_duration => 2.0, :loss_fraction => 0.01,
    :constraints => Dict{Symbol,Bool}(:BalanceConstraint => true, :StorageCapacityConstraint => true,
                                      :StorageMinDurationConstraint => true, :StorageMaxDurationConstraint => true))
const POWER_EDGE = Dict{Symbol,Any}(:has_capacity => true, :can_expand => true, :investment_cost => 1.0,
                                    :constraints => Dict{Symbol,Bool}(:CapacityConstraint => true))

function test_duration_constraints()
    @testset "a capacitated flow edge is the power for the duration constraints" begin
        system, asset = make_case(:Heat; storage = DURATION_STORAGE, edge = POWER_EDGE)
        @test asset.storage.discharge_edge === asset.flow_edge && asset.storage.charge_edge === asset.flow_edge
        build_test_model(system)
        @test isempty(flow_pos(asset.flow_edge))
        power = value(capacity(asset.flow_edge))
        volume = value(capacity(asset.storage))
        f = value.(flow(asset.flow_edge))
        @test power > 1.0
        @test volume ≈ 2.0 * power atol = 1e-6
        @test maximum(abs.(f)) <= power + 1e-6
        @test f[1] > 0 && f[2] < 0 && f[3] < 0
    end
    @testset "a duration constraint without a capacitated flow edge is rejected" begin
        @test_throws "need a flow_edge with has_capacity = true" make_case(:Heat; storage = DURATION_STORAGE)
    end
end

# The implicit min-max constraint is added to a long-duration Battery only with representative subperiods.
function battery_storage(; tdr::Bool)
    system = make_test_system([Electricity])
    tdr && (system.time_data[:Electricity] = tdr_timedata(Electricity))
    n = length(system.time_data[:Electricity].time_interval)
    source = make_supply_node(Electricity, :source, system.time_data[:Electricity], fill(1.0, n))
    sink = make_demand_node(Electricity, :sink, system.time_data[:Electricity], fill(1.0, n))
    push_locations!(system, source, sink)
    asset = make(Battery, Dict{Symbol,Any}(:id => :battery, :storage_long_duration => true,
        :charge_start_vertex => :source, :discharge_end_vertex => :sink), system)
    return asset.battery_storage
end

function test_long_duration_gate()
    @testset "long-duration Battery: implicit min-max only with representative subperiods" begin
        @test !has_implicit(battery_storage(tdr = false))
        @test has_implicit(battery_storage(tdr = true))
    end
end

test_one_signed_flow()
test_simple_input_and_tags()
test_long_duration()
test_lossy_flow_edge()
test_net_inflow_matches_balance()
test_variable_om_cost()
test_rejected_inputs()
test_duration_constraints()
test_long_duration_gate()

end # module TestAssetNetFlowStorageBalance
