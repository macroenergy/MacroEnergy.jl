module TestAccessorAllocation

using Test
using JuMP
using HiGHS
using MacroEnergy

include("asset_tests/asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    array_container,
    Battery,
    Electricity,
    EdgeWithUC,
    flow,
    get_balance,
    make,
    storage_level,
    time_interval,
    ucommit,
    ushut,
    ustart

function make_battery_fixture()
    system = make_test_system([Electricity]; num_steps = 24)
    elec_timedata = system.time_data[:Electricity]

    source = make_supply_node(Electricity, :battery_source, elec_timedata, fill(1.0, 24))
    sink = make_demand_node(Electricity, :battery_sink, elec_timedata, fill(1.0, 24))
    push_locations!(system, source, sink)

    battery_data = Dict{Symbol,Any}(
        :id => :battery_test,
        :storage_can_expand => false,
        :storage_can_retire => false,
        :discharge_can_expand => false,
        :discharge_can_retire => false,
        :charge_can_expand => false,
        :charge_can_retire => false,
        :storage_existing_capacity => 10.0,
        :discharge_existing_capacity => 10.0,
        :charge_existing_capacity => 10.0,
        :charge_efficiency => 0.8,
        :discharge_efficiency => 0.5,
        :charge_start_vertex => :battery_source,
        :discharge_end_vertex => :battery_sink,
    )
    asset = make(Battery, battery_data, system)
    push!(system.assets, asset)
    model = build_test_model(system)

    return (; system, asset, model, sink)
end

# These accessors must allocate nothing
const ALLOWED_ACCESSOR_ALLOCATION = 0

function test_flow_allocation()
    fx = make_battery_fixture()
    e = fx.asset.charge_edge
    flow(e, 1)  # warm-up / compile
    bytes = @allocated flow(e, 1)
    @info "flow(e,t) allocated $(bytes) bytes"
    @test flow(e, 1) isa VariableRef
    @test bytes <= ALLOWED_ACCESSOR_ALLOCATION
    return nothing
end

function test_storage_level_allocation()
    fx = make_battery_fixture()
    g = fx.asset.battery_storage
    storage_level(g, 1)
    bytes = @allocated storage_level(g, 1)
    @info "storage_level(g,t) allocated $(bytes) bytes"
    @test storage_level(g, 1) isa VariableRef
    @test bytes <= ALLOWED_ACCESSOR_ALLOCATION
    return nothing
end

function test_get_balance_allocation()
    fx = make_battery_fixture()
    v = fx.sink
    get_balance(v, :demand, 1)
    bytes = @allocated get_balance(v, :demand, 1)
    @info "get_balance(v,i,t) allocated $(bytes) bytes"
    @test get_balance(v, :demand, 1) isa AffExpr
    @test bytes == 0
    return nothing
end

# `start` mimics a Benders subproblem's time_interval (see make_test_timedata):
# start=1 is the common/Monolithic/Myopic case and Benders' first subproblem;
# start!=1 is every other Benders subproblem
function make_uc_edge_fixture(; start::Int = 1)
    model = Model(HiGHS.Optimizer)
    set_silent(model)

    timedata = make_test_timedata(Electricity, 24; start = start)
    dummy_start = make_free_node(Electricity, :uc_start, timedata)
    dummy_end = make_free_node(Electricity, :uc_end, timedata)

    e = EdgeWithUC{Electricity}(;
        id = :uc_test_edge,
        timedata = timedata,
        start_vertex = dummy_start,
        end_vertex = dummy_end,
    )
    # array_container matches operation_model! exactly: container = Array only
    # when time_interval(e) is one-based, else JuMP.Containers.DenseAxisArray.
    c = array_container(time_interval(e))
    e.flow = @variable(model, [t in time_interval(e)], container = c, lower_bound = 0.0)
    e.ucommit = @variable(model, [t in time_interval(e)], container = c, lower_bound = 0.0)
    e.ustart = @variable(model, [t in time_interval(e)], container = c, lower_bound = 0.0)
    e.ushut = @variable(model, [t in time_interval(e)], container = c, lower_bound = 0.0)
    return e
end

function test_uc_accessor_allocation()
    e = make_uc_edge_fixture()

    ucommit(e, 1); ustart(e, 1); ushut(e, 1)  # warm-up / compile

    b_ucommit = @allocated ucommit(e, 1)
    b_ustart = @allocated ustart(e, 1)
    b_ushut = @allocated ushut(e, 1)
    @info "ucommit/ustart/ushut allocated $(b_ucommit)/$(b_ustart)/$(b_ushut) bytes"

    @test ucommit(e, 1) isa VariableRef
    @test ustart(e, 1) isa VariableRef
    @test ushut(e, 1) isa VariableRef
    @test flow(e) isa Vector{VariableRef}
    @test b_ucommit <= ALLOWED_ACCESSOR_ALLOCATION
    @test b_ustart <= ALLOWED_ACCESSOR_ALLOCATION
    @test b_ushut <= ALLOWED_ACCESSOR_ALLOCATION
    return nothing
end

function test_array_container()
    @test array_container(1:24) === Array
    @test array_container(169:192) === JuMP.Containers.DenseAxisArray
    return nothing
end

function test_uc_accessor_non_one_based()
    e = make_uc_edge_fixture(; start = 169)

    @test flow(e) isa JuMP.Containers.DenseAxisArray
    @test flow(e, 169) isa VariableRef
    @test ucommit(e, 169) isa VariableRef
    @test ustart(e, 169) isa VariableRef
    @test ushut(e, 169) isa VariableRef
    @test_throws KeyError flow(e, 1)  # 1 isn't a valid index for this subproblem's window
    return nothing
end

@testset "Accessor allocation" begin
    @testset "flow(e,t)" begin
        test_flow_allocation()
    end
    @testset "storage_level(g,t)" begin
        test_storage_level_allocation()
    end
    @testset "get_balance(v,i,t)" begin
        test_get_balance_allocation()
    end
    @testset "ucommit/ustart/ushut(e,t)" begin
        test_uc_accessor_allocation()
    end
    @testset "array_container" begin
        test_array_container()
    end
    @testset "Non-one-based time_interval (Benders subproblem) container fallback" begin
        test_uc_accessor_non_one_based()
    end
end

end # module TestAccessorAllocation
