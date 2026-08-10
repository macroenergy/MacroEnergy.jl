module TestAssetSyntheticLiquidFuelsBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    CO2,
    CO2Captured,
    Electricity,
    Hydrogen,
    LiquidFuels,
    SyntheticLiquidFuels,
    flow,
    make

function make_syntheticliquidfuels_case(style::Symbol)
    system = make_test_system([CO2Captured, Electricity, Hydrogen, LiquidFuels, CO2])

    co2_source = make_supply_node(CO2Captured, :co2_source, system.time_data[:CO2Captured], [2.0, 2.0, 2.0])
    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    h2_source = make_supply_node(Hydrogen, :h2_source, system.time_data[:Hydrogen], [2.0, 2.0, 2.0])
    gasoline_sink = make_demand_node(LiquidFuels, :gasoline_sink, system.time_data[:LiquidFuels], [1.0, 2.0, 3.0])
    jetfuel_sink = make_free_node(LiquidFuels, :jetfuel_sink, system.time_data[:LiquidFuels])
    diesel_sink = make_free_node(LiquidFuels, :diesel_sink, system.time_data[:LiquidFuels])
    co2_emission_sink = make_free_node(CO2, :co2_emission_sink, system.time_data[:CO2])
    push_locations!(system, co2_source, elec_source, h2_source, gasoline_sink, jetfuel_sink, diesel_sink, co2_emission_sink)

    asset = make(
        SyntheticLiquidFuels,
        Dict{Symbol,Any}(
            :id => :synthetic_liquid_fuels_test,
            :co2_sink => :co2_emission_sink,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 20.0,
            :gasoline_production => 0.2,
            :jetfuel_production => 0.1,
            :diesel_production => 0.15,
            :electricity_consumption => 0.1,
            :h2_consumption => 0.2,
            :emission_rate => 0.05,
            :co2_captured_start_vertex => :co2_source,
            :elec_start_vertex => :elec_source,
            :h2_start_vertex => :h2_source,
            :gasoline_end_vertex => :gasoline_sink,
            :jetfuel_end_vertex => :jetfuel_sink,
            :diesel_end_vertex => :diesel_sink,
            :co2_emission_end_vertex => :co2_emission_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.synthetic_liquid_fuels_transform
    if style == :add_balance
        transform.balance_data = Dict{Symbol,Any}()
        @add_balance(transform, :gasoline, 0.2 * flow(asset.co2_captured_edge) == flow(asset.gasoline_edge))
        @add_balance(transform, :jetfuel, 0.1 * flow(asset.co2_captured_edge) == flow(asset.jetfuel_edge))
        @add_balance(transform, :diesel, 0.15 * flow(asset.co2_captured_edge) == flow(asset.diesel_edge))
        @add_balance(transform, :electricity, 0.1 * flow(asset.co2_captured_edge) == flow(asset.elec_edge))
        @add_balance(transform, :h2, 0.2 * flow(asset.co2_captured_edge) == flow(asset.h2_edge))
        @add_balance(transform, :emissions, 0.05 * flow(asset.co2_captured_edge) == flow(asset.co2_emission_edge))
    elseif style != :default
        error("Unsupported SyntheticLiquidFuels balance style: $style")
    end

    return (; system, asset)
end

function assert_syntheticliquidfuels_solution(asset, model)
    expected_co2_captured = [5.0, 10.0, 15.0]
    expected_gasoline = [1.0, 2.0, 3.0]
    expected_jetfuel = [0.5, 1.0, 1.5]
    expected_diesel = [0.75, 1.5, 2.25]
    expected_elec = [0.5, 1.0, 1.5]
    expected_h2 = [1.0, 2.0, 3.0]
    expected_co2_emission = [0.25, 0.5, 0.75]

    @test objective_value(model) ≈ 75.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.co2_captured_edge, t)) ≈ expected_co2_captured[t] atol = 1e-8
        @test value(flow(asset.gasoline_edge, t)) ≈ expected_gasoline[t] atol = 1e-8
        @test value(flow(asset.jetfuel_edge, t)) ≈ expected_jetfuel[t] atol = 1e-8
        @test value(flow(asset.diesel_edge, t)) ≈ expected_diesel[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
        @test value(flow(asset.h2_edge, t)) ≈ expected_h2[t] atol = 1e-8
        @test value(flow(asset.co2_emission_edge, t)) ≈ expected_co2_emission[t] atol = 1e-8
    end
end

function test_asset_syntheticliquidfuels_balance()
    @testset "SyntheticLiquidFuels Small Solve Cases" begin
        default_case = make_syntheticliquidfuels_case(:default)
        add_balance_case = make_syntheticliquidfuels_case(:add_balance)

        default_model = build_test_model(default_case.system)
        add_balance_model = build_test_model(add_balance_case.system)

        assert_syntheticliquidfuels_solution(default_case.asset, default_model)
        assert_syntheticliquidfuels_solution(add_balance_case.asset, add_balance_model)

        for t in 1:3
            @test value(flow(default_case.asset.co2_captured_edge, t)) ≈ value(flow(add_balance_case.asset.co2_captured_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.gasoline_edge, t)) ≈ value(flow(add_balance_case.asset.gasoline_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.jetfuel_edge, t)) ≈ value(flow(add_balance_case.asset.jetfuel_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.diesel_edge, t)) ≈ value(flow(add_balance_case.asset.diesel_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.elec_edge, t)) ≈ value(flow(add_balance_case.asset.elec_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.h2_edge, t)) ≈ value(flow(add_balance_case.asset.h2_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.co2_emission_edge, t)) ≈ value(flow(add_balance_case.asset.co2_emission_edge, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(add_balance_model) atol = 1e-8
    end

    return nothing
end

test_asset_syntheticliquidfuels_balance()

end # module TestAssetSyntheticLiquidFuelsBalance
