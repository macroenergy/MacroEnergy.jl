module TestAssetCO2InjectionBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    CO2Captured,
    CO2Injection,
    flow,
    make

function make_co2injection_case(style::Symbol)
    system = make_test_system([CO2Captured])

    co2_source = make_supply_node(CO2Captured, :co2_source, system.time_data[:CO2Captured], [1.0, 1.0, 1.0])
    storage_sink = make_demand_node(CO2Captured, :storage_sink, system.time_data[:CO2Captured], [1.0, 2.0, 3.0])
    push_locations!(system, co2_source, storage_sink)

    asset = make(
        CO2Injection,
        Dict{Symbol,Any}(
            :id => :co2_injection_test,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 10.0,
            :co2_source => :co2_source,
            :co2_storage => :storage_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.co2injection_transform
    if style == :add_balance
        transform.balance_data = Dict{Symbol,Any}()
        @add_balance(transform, :injection, flow(asset.co2_storage_edge) == flow(asset.co2_captured_edge))
    elseif style != :default
        error("Unsupported CO2Injection balance style: $style")
    end

    return (; system, asset)
end

function assert_co2injection_solution(asset, model)
    expected_flow = [1.0, 2.0, 3.0]

    @test objective_value(model) ≈ 6.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.co2_captured_edge, t)) ≈ expected_flow[t] atol = 1e-8
        @test value(flow(asset.co2_storage_edge, t)) ≈ expected_flow[t] atol = 1e-8
    end
end

function test_asset_co2injection_balance()
    @testset "CO2Injection Small Solve Cases" begin
        default_case = make_co2injection_case(:default)
        add_balance_case = make_co2injection_case(:add_balance)

        default_model = build_test_model(default_case.system)
        add_balance_model = build_test_model(add_balance_case.system)

        assert_co2injection_solution(default_case.asset, default_model)
        assert_co2injection_solution(add_balance_case.asset, add_balance_model)

        for t in 1:3
            @test value(flow(default_case.asset.co2_captured_edge, t)) ≈ value(flow(add_balance_case.asset.co2_captured_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.co2_storage_edge, t)) ≈ value(flow(add_balance_case.asset.co2_storage_edge, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(add_balance_model) atol = 1e-8
    end

    return nothing
end

test_asset_co2injection_balance()

end # module TestAssetCO2InjectionBalance
