module TestAssetMustRunBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    Electricity,
    MustRun,
    flow,
    make

function make_mustrun_case()
    system = make_test_system([Electricity])

    sink = make_demand_node(Electricity, :mustrun_sink, system.time_data[:Electricity], [2.0, 2.0, 2.0])
    push_locations!(system, sink)

    asset = make(
        MustRun,
        Dict{Symbol,Any}(
            :id => :mustrun_test,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 2.0,
            :elec_end_vertex => :mustrun_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    return (; system, asset)
end

function assert_mustrun_solution(asset, model)
    expected_flow = [2.0, 2.0, 2.0]

    @test objective_value(model) ≈ 0.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.elec_edge, t)) ≈ expected_flow[t] atol = 1e-8
    end
end

function test_asset_mustrun_balance()
    @testset "MustRun Small Solve Case" begin
        mustrun_case = make_mustrun_case()
        mustrun_model = build_test_model(mustrun_case.system)

        assert_mustrun_solution(mustrun_case.asset, mustrun_model)
    end

    return nothing
end

test_asset_mustrun_balance()

end # module TestAssetMustRunBalance
