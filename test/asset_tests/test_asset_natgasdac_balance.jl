module TestAssetNaturalGasDACBalance

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
    NaturalGas,
    NaturalGasDAC,
    flow,
    make

function make_natgasdac_case(style::Symbol)
    system = make_test_system([CO2, NaturalGas, Electricity, CO2Captured])

    co2_source = make_supply_node(CO2, :co2_source, system.time_data[:CO2], [3.0, 3.0, 3.0])
    natgas_source = make_supply_node(NaturalGas, :natgas_source, system.time_data[:NaturalGas], [2.0, 2.0, 2.0])
    elec_sink = make_free_node(Electricity, :elec_sink, system.time_data[:Electricity])
    co2_emission_sink = make_free_node(CO2, :co2_emission_sink, system.time_data[:CO2])
    captured_sink = make_demand_node(CO2Captured, :captured_sink, system.time_data[:CO2Captured], [1.0, 2.0, 3.0])
    push_locations!(system, co2_source, natgas_source, elec_sink, co2_emission_sink, captured_sink)

    asset = make(
        NaturalGasDAC,
        Dict{Symbol,Any}(
            :id => :natgas_dac_test,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 10.0,
            :electricity_production => 0.5,
            :fuel_consumption => 2.0,
            :emission_rate => 0.1,
            :capture_rate => 0.2,
            :co2_sink => :co2_source,
            :natgas_start_vertex => :natgas_source,
            :elec_end_vertex => :elec_sink,
            :co2_emission_end_vertex => :co2_emission_sink,
            :co2_captured_end_vertex => :captured_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.natgasdac_transform
    if style == :add_balance
        transform.balance_data = Dict{Symbol,Any}()
        @add_balance(transform, :elec_production, flow(asset.elec_edge) == 0.5 * flow(asset.co2_edge))
        @add_balance(transform, :fuel_consumption, 2.0 * flow(asset.co2_edge) == flow(asset.natgas_edge))
        @add_balance(transform, :emissions, 0.1 * flow(asset.natgas_edge) == flow(asset.co2_emission_edge))
        @add_balance(transform, :capture, 0.2 * flow(asset.natgas_edge) + flow(asset.co2_edge) == flow(asset.co2_captured_edge))
    elseif style != :default
        error("Unsupported NaturalGasDAC balance style: $style")
    end

    return (; system, asset)
end

function assert_natgasdac_solution(asset, model)
    expected_captured = [1.0, 2.0, 3.0]
    expected_co2 = [5 / 7, 10 / 7, 15 / 7]
    expected_natgas = [10 / 7, 20 / 7, 30 / 7]
    expected_emissions = [1 / 7, 2 / 7, 3 / 7]
    expected_elec = [5 / 14, 10 / 14, 15 / 14]

    @test objective_value(model) ≈ 30.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.co2_captured_edge, t)) ≈ expected_captured[t] atol = 1e-8
        @test value(flow(asset.co2_edge, t)) ≈ expected_co2[t] atol = 1e-8
        @test value(flow(asset.natgas_edge, t)) ≈ expected_natgas[t] atol = 1e-8
        @test value(flow(asset.co2_emission_edge, t)) ≈ expected_emissions[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
    end
end

function test_asset_natgasdac_balance()
    @testset "NaturalGasDAC Small Solve Cases" begin
        default_case = make_natgasdac_case(:default)
        add_balance_case = make_natgasdac_case(:add_balance)

        default_model = build_test_model(default_case.system)
        add_balance_model = build_test_model(add_balance_case.system)

        assert_natgasdac_solution(default_case.asset, default_model)
        assert_natgasdac_solution(add_balance_case.asset, add_balance_model)

        for t in 1:3
            @test value(flow(default_case.asset.co2_captured_edge, t)) ≈ value(flow(add_balance_case.asset.co2_captured_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.co2_edge, t)) ≈ value(flow(add_balance_case.asset.co2_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.natgas_edge, t)) ≈ value(flow(add_balance_case.asset.natgas_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.co2_emission_edge, t)) ≈ value(flow(add_balance_case.asset.co2_emission_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.elec_edge, t)) ≈ value(flow(add_balance_case.asset.elec_edge, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(add_balance_model) atol = 1e-8
    end

    return nothing
end

test_asset_natgasdac_balance()

end # module TestAssetNaturalGasDACBalance
