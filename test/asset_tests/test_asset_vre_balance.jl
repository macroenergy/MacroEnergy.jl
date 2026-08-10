module TestAssetVREBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    Electricity,
    VRE,
    flow,
    make

function make_vre_case()
    system = make_test_system([Electricity])

    sink = make_demand_node(Electricity, :vre_sink, system.time_data[:Electricity], [2.0, 4.0, 1.0])
    push_locations!(system, sink)

    asset = make(
        VRE,
        Dict{Symbol,Any}(
            :id => :vre_test,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 4.0,
            :availability => [0.5, 1.0, 0.25],
            :end_vertex => :vre_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    return (; system, asset)
end

function assert_vre_solution(asset, model)
    expected_flow = [2.0, 4.0, 1.0]

    @test objective_value(model) ≈ 0.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.edge, t)) ≈ expected_flow[t] atol = 1e-8
    end
end

function test_asset_vre_balance()
    @testset "VRE Small Solve Case" begin
        vre_case = make_vre_case()
        vre_model = build_test_model(vre_case.system)

        assert_vre_solution(vre_case.asset, vre_model)
    end

    return nothing
end

test_asset_vre_balance()

end # module TestAssetVREBalance
