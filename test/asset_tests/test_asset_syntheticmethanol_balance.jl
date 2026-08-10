module TestAssetSyntheticMethanolBalance

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
    Methanol,
    SyntheticMethanol,
    flow,
    make

function make_syntheticmethanol_case(style::Symbol)
    system = make_test_system([CO2Captured, Electricity, Hydrogen, Methanol, CO2])

    co2_source = make_supply_node(CO2Captured, :co2_source, system.time_data[:CO2Captured], [2.0, 2.0, 2.0])
    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    h2_source = make_supply_node(Hydrogen, :h2_source, system.time_data[:Hydrogen], [2.0, 2.0, 2.0])
    ch3oh_sink = make_demand_node(Methanol, :ch3oh_sink, system.time_data[:Methanol], [1.0, 2.0, 3.0])
    co2_emission_sink = make_free_node(CO2, :co2_emission_sink, system.time_data[:CO2])
    push_locations!(system, co2_source, elec_source, h2_source, ch3oh_sink, co2_emission_sink)

    asset = make(
        SyntheticMethanol,
        Dict{Symbol,Any}(
            :id => :synthetic_methanol_test,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 10.0,
            :co2_consumption => 0.5,
            :electricity_consumption => 0.3,
            :h2_consumption => 0.4,
            :emission_rate => 0.2,
            :co2_captured_start_vertex => :co2_source,
            :elec_start_vertex => :elec_source,
            :h2_start_vertex => :h2_source,
            :ch3oh_end_vertex => :ch3oh_sink,
            :co2_emission_end_vertex => :co2_emission_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.synthetic_methanol_transform
    if style == :add_balance
        transform.balance_data = Dict{Symbol,Any}()
        @add_balance(transform, :co2, 0.5 * flow(asset.ch3oh_edge) == flow(asset.co2_captured_edge))
        @add_balance(transform, :electricity, 0.3 * flow(asset.ch3oh_edge) == flow(asset.elec_edge))
        @add_balance(transform, :h2, 0.4 * flow(asset.ch3oh_edge) == flow(asset.h2_edge))
        @add_balance(transform, :emissions, 0.1 * flow(asset.ch3oh_edge) == flow(asset.co2_emission_edge))
    elseif style != :default
        error("Unsupported SyntheticMethanol balance style: $style")
    end

    return (; system, asset)
end

function assert_syntheticmethanol_solution(asset, model)
    expected_ch3oh = [1.0, 2.0, 3.0]
    expected_co2 = [0.5, 1.0, 1.5]
    expected_elec = [0.3, 0.6, 0.9]
    expected_h2 = [0.4, 0.8, 1.2]
    expected_co2_emission = [0.1, 0.2, 0.3]

    @test objective_value(model) ≈ 12.6 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.ch3oh_edge, t)) ≈ expected_ch3oh[t] atol = 1e-8
        @test value(flow(asset.co2_captured_edge, t)) ≈ expected_co2[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
        @test value(flow(asset.h2_edge, t)) ≈ expected_h2[t] atol = 1e-8
        @test value(flow(asset.co2_emission_edge, t)) ≈ expected_co2_emission[t] atol = 1e-8
    end
end

function test_asset_syntheticmethanol_balance()
    @testset "SyntheticMethanol Small Solve Cases" begin
        default_case = make_syntheticmethanol_case(:default)
        add_balance_case = make_syntheticmethanol_case(:add_balance)

        default_model = build_test_model(default_case.system)
        add_balance_model = build_test_model(add_balance_case.system)

        assert_syntheticmethanol_solution(default_case.asset, default_model)
        assert_syntheticmethanol_solution(add_balance_case.asset, add_balance_model)

        for t in 1:3
            @test value(flow(default_case.asset.ch3oh_edge, t)) ≈ value(flow(add_balance_case.asset.ch3oh_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.co2_captured_edge, t)) ≈ value(flow(add_balance_case.asset.co2_captured_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.elec_edge, t)) ≈ value(flow(add_balance_case.asset.elec_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.h2_edge, t)) ≈ value(flow(add_balance_case.asset.h2_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.co2_emission_edge, t)) ≈ value(flow(add_balance_case.asset.co2_emission_edge, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(add_balance_model) atol = 1e-8
    end

    return nothing
end

test_asset_syntheticmethanol_balance()

end # module TestAssetSyntheticMethanolBalance
