module TestNodeSupplyAccessors

using Test
using JuMP
using MacroEnergy

include("asset_tests/asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    BalanceConstraint,
    BalanceData,
    Electricity,
    Node,
    TimeData,
    max_supply,
    min_supply,
    non_served_demand,
    price_supply,
    supply_flow,
    supply_segment_name,
    supply_segments

function make_supply_test_node()
    timedata = make_test_timedata(Electricity, 3)
    return make_supply_node(Electricity, :test_supply_node, timedata, [1.0, 10.0, 2.0])
end

function test_supply_accessor_correctness()
    n = make_supply_test_node()

    @test supply_segment_name(n, 1) == :grid
    @test collect(supply_segments(n)) == [1]
    @test min_supply(n, 1) == [0.0]
    @test max_supply(n, 1) == [Inf]
    @test price_supply(n, 1) == [1.0, 10.0, 2.0]
    @test min_supply(n, 1, 1) == 0.0
    @test max_supply(n, 1, 2) == Inf
    @test price_supply(n, 1, 3) == 2.0

    return n
end

function test_supply_accessor_allocation()
    n = make_supply_test_node()

    supply_segment_name(n, 1)
    min_supply(n, 1, 1)
    max_supply(n, 1, 1)
    price_supply(n, 1, 1)  # warm-up / compile

    b_name = @allocated supply_segment_name(n, 1)
    b_min = @allocated min_supply(n, 1, 1)
    b_max = @allocated max_supply(n, 1, 1)
    b_price = @allocated price_supply(n, 1, 1)
    @info "supply_segment_name/min_supply/max_supply/price_supply allocated $(b_name)/$(b_min)/$(b_max)/$(b_price) bytes"

    @test b_name == 0
    @test b_min == 0
    @test b_max == 0
    @test b_price == 0
    return nothing
end

function make_supply_flow_fixture()
    timedata = make_test_timedata(Electricity, 3)
    source = make_supply_node(Electricity, :sf_source, timedata, [1.0, 10.0, 2.0])
    system = make_test_system([Electricity]; num_steps = 3)
    push_locations!(system, source)
    model = build_test_model(system)
    return (; system, model, source)
end

function test_supply_flow_allocation()
    fx = make_supply_flow_fixture()
    n = fx.source
    supply_flow(n, 1, 1)  # warm-up / compile
    bytes = @allocated supply_flow(n, 1, 1)
    @info "supply_flow(n,s,t) allocated $(bytes) bytes"
    @test supply_flow(n, 1, 1) isa VariableRef
    @test bytes == 0
    return nothing
end

function make_non_served_demand_fixture()
    timedata = make_test_timedata(Electricity, 3)
    sink = Node{Electricity}(;
        id = :nsd_sink,
        timedata = timedata,
        constraints = [BalanceConstraint()],
        balance_data = Dict(:demand => BalanceData()),
        demand = [1.0, 1.0, 1.0],
        max_nsd = [1000.0],
    )
    system = make_test_system([Electricity]; num_steps = 3)
    push_locations!(system, sink)
    model = build_test_model(system)
    return (; system, model, sink)
end

function test_non_served_demand_allocation()
    fx = make_non_served_demand_fixture()
    n = fx.sink
    non_served_demand(n, 1, 1)  # warm-up / compile
    bytes = @allocated non_served_demand(n, 1, 1)
    @info "non_served_demand(n,s,t) allocated $(bytes) bytes"
    @test non_served_demand(n, 1, 1) isa VariableRef
    @test bytes == 0
    return nothing
end

@testset "Node supply accessors" begin
    @testset "correctness" begin
        test_supply_accessor_correctness()
    end
    @testset "allocation" begin
        test_supply_accessor_allocation()
    end
    @testset "supply_flow allocation" begin
        test_supply_flow_allocation()
    end
    @testset "non_served_demand allocation" begin
        test_non_served_demand_allocation()
    end
end

end # module TestNodeSupplyAccessors
