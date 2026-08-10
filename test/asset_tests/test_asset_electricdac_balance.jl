module TestAssetElectricDACBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    CO2,
    CO2Captured,
    ElectricDAC,
    Electricity,
    flow,
    make

function make_electricdac_case(style::Symbol)
    system = make_test_system([CO2, Electricity, CO2Captured])

    co2_source = make_supply_node(CO2, :co2_source, system.time_data[:CO2], [3.0, 3.0, 3.0])
    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    captured_sink = make_demand_node(CO2Captured, :captured_sink, system.time_data[:CO2Captured], [1.0, 2.0, 3.0])
    push_locations!(system, co2_source, elec_source, captured_sink)

    asset = make(
        ElectricDAC,
        Dict{Symbol,Any}(
            :id => :electric_dac_test,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 10.0,
            :electricity_consumption => 2.0,
            :co2_sink => :co2_source,
            :elec_start_vertex => :elec_source,
            :co2_captured_end_vertex => :captured_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.electricdac_transform
    if style == :add_balance
        transform.balance_data = Dict{Symbol,Any}()
        @add_balance(transform, :co2, flow(asset.co2_captured_edge) == flow(asset.co2_edge))
        @add_balance(transform, :electricity, 2.0 * flow(asset.co2_captured_edge) == flow(asset.elec_edge))
    elseif style != :default
        error("Unsupported ElectricDAC balance style: $style")
    end

    return (; system, asset)
end

function assert_electricdac_solution(asset, model)
    expected_captured = [1.0, 2.0, 3.0]
    expected_elec = [2.0, 4.0, 6.0]

    @test objective_value(model) ≈ 30.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.co2_captured_edge, t)) ≈ expected_captured[t] atol = 1e-8
        @test value(flow(asset.co2_edge, t)) ≈ expected_captured[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
    end
end

function test_asset_electricdac_balance()
    @testset "ElectricDAC Small Solve Cases" begin
        default_case = make_electricdac_case(:default)
        add_balance_case = make_electricdac_case(:add_balance)

        default_model = build_test_model(default_case.system)
        add_balance_model = build_test_model(add_balance_case.system)

        assert_electricdac_solution(default_case.asset, default_model)
        assert_electricdac_solution(add_balance_case.asset, add_balance_model)

        for t in 1:3
            @test value(flow(default_case.asset.co2_captured_edge, t)) ≈ value(flow(add_balance_case.asset.co2_captured_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.co2_edge, t)) ≈ value(flow(add_balance_case.asset.co2_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.elec_edge, t)) ≈ value(flow(add_balance_case.asset.elec_edge, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(add_balance_model) atol = 1e-8
    end

    return nothing
end

test_asset_electricdac_balance()

end # module TestAssetElectricDACBalance
