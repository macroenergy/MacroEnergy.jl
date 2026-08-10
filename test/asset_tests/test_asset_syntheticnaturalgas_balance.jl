module TestAssetSyntheticNaturalGasBalance

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
    NaturalGas,
    SyntheticNaturalGas,
    flow,
    make

function make_syntheticnaturalgas_case(style::Symbol)
    system = make_test_system([CO2Captured, Electricity, Hydrogen, NaturalGas, CO2])

    co2_source = make_supply_node(CO2Captured, :co2_source, system.time_data[:CO2Captured], [2.0, 2.0, 2.0])
    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    h2_source = make_supply_node(Hydrogen, :h2_source, system.time_data[:Hydrogen], [2.0, 2.0, 2.0])
    natgas_sink = make_demand_node(NaturalGas, :natgas_sink, system.time_data[:NaturalGas], [1.0, 2.0, 3.0])
    co2_emission_sink = make_free_node(CO2, :co2_emission_sink, system.time_data[:CO2])
    push_locations!(system, co2_source, elec_source, h2_source, natgas_sink, co2_emission_sink)

    asset = make(
        SyntheticNaturalGas,
        Dict{Symbol,Any}(
            :id => :synthetic_natural_gas_test,
            :co2_sink => :co2_emission_sink,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 20.0,
            :natgas_production => 0.5,
            :electricity_consumption => 0.25,
            :h2_consumption => 0.5,
            :emission_rate => 0.1,
            :co2_captured_start_vertex => :co2_source,
            :elec_start_vertex => :elec_source,
            :h2_start_vertex => :h2_source,
            :natgas_end_vertex => :natgas_sink,
            :co2_emission_end_vertex => :co2_emission_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.synthetic_natural_gas_transform
    if style == :add_balance
        transform.balance_data = Dict{Symbol,Any}()
        @add_balance(transform, :natgas, 0.5 * flow(asset.co2_captured_edge) == flow(asset.natgas_edge))
        @add_balance(transform, :electricity, 0.25 * flow(asset.co2_captured_edge) == flow(asset.elec_edge))
        @add_balance(transform, :h2, 0.5 * flow(asset.co2_captured_edge) == flow(asset.h2_edge))
        @add_balance(transform, :emissions, 0.1 * flow(asset.co2_captured_edge) == flow(asset.co2_emission_edge))
    elseif style != :default
        error("Unsupported SyntheticNaturalGas balance style: $style")
    end

    return (; system, asset)
end

function assert_syntheticnaturalgas_solution(asset, model)
    expected_co2_captured = [2.0, 4.0, 6.0]
    expected_natgas = [1.0, 2.0, 3.0]
    expected_elec = [0.5, 1.0, 1.5]
    expected_h2 = [1.0, 2.0, 3.0]
    expected_co2_emission = [0.2, 0.4, 0.6]

    @test objective_value(model) ≈ 39.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.co2_captured_edge, t)) ≈ expected_co2_captured[t] atol = 1e-8
        @test value(flow(asset.natgas_edge, t)) ≈ expected_natgas[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
        @test value(flow(asset.h2_edge, t)) ≈ expected_h2[t] atol = 1e-8
        @test value(flow(asset.co2_emission_edge, t)) ≈ expected_co2_emission[t] atol = 1e-8
    end
end

function test_asset_syntheticnaturalgas_balance()
    @testset "SyntheticNaturalGas Small Solve Cases" begin
        default_case = make_syntheticnaturalgas_case(:default)
        add_balance_case = make_syntheticnaturalgas_case(:add_balance)

        default_model = build_test_model(default_case.system)
        add_balance_model = build_test_model(add_balance_case.system)

        assert_syntheticnaturalgas_solution(default_case.asset, default_model)
        assert_syntheticnaturalgas_solution(add_balance_case.asset, add_balance_model)

        for t in 1:3
            @test value(flow(default_case.asset.co2_captured_edge, t)) ≈ value(flow(add_balance_case.asset.co2_captured_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.natgas_edge, t)) ≈ value(flow(add_balance_case.asset.natgas_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.elec_edge, t)) ≈ value(flow(add_balance_case.asset.elec_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.h2_edge, t)) ≈ value(flow(add_balance_case.asset.h2_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.co2_emission_edge, t)) ≈ value(flow(add_balance_case.asset.co2_emission_edge, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(add_balance_model) atol = 1e-8
    end

    return nothing
end

test_asset_syntheticnaturalgas_balance()

end # module TestAssetSyntheticNaturalGasBalance
