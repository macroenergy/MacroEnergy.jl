module TestAssetThermalHydrogenCCSBalance

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
    ThermalHydrogenCCS,
    flow,
    make

function make_thermalhydrogenccs_case(style::Symbol)
    system = make_test_system([Hydrogen, Electricity, NaturalGas, CO2, CO2Captured])

    fuel_source = make_supply_node(NaturalGas, :fuel_source, system.time_data[:NaturalGas], [2.0, 2.0, 2.0])
    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    h2_sink = make_demand_node(Hydrogen, :h2_sink, system.time_data[:Hydrogen], [1.0, 2.0, 3.0])
    co2_sink = make_free_node(CO2, :co2_sink, system.time_data[:CO2])
    co2_captured_sink = make_free_node(CO2Captured, :co2_captured_sink, system.time_data[:CO2Captured])
    push_locations!(system, fuel_source, elec_source, h2_sink, co2_sink, co2_captured_sink)

    asset = make(
        ThermalHydrogenCCS,
        Dict{Symbol,Any}(
            :id => :thermal_hydrogen_ccs_test,
            :timedata => "Hydrogen",
            :fuel_commodity => "NaturalGas",
            :co2_sink => :co2_sink,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 10.0,
            :fuel_consumption => 2.0,
            :electricity_consumption => 0.5,
            :emission_rate => 0.1,
            :capture_rate => 0.15,
            :fuel_start_vertex => :fuel_source,
            :elec_start_vertex => :elec_source,
            :h2_end_vertex => :h2_sink,
            :co2_captured_end_vertex => :co2_captured_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.thermalhydrogenccs_transform
    if style == :add_balance
        transform.balance_data = Dict{Symbol,Any}()
        @add_balance(transform, :fuel, 2.0 * flow(asset.h2_edge) == flow(asset.fuel_edge))
        @add_balance(transform, :electricity, 0.5 * flow(asset.h2_edge) == flow(asset.elec_edge))
        @add_balance(transform, :emissions, 0.2 * flow(asset.h2_edge) == flow(asset.co2_edge))
        @add_balance(transform, :capture, 0.3 * flow(asset.h2_edge) == flow(asset.co2_captured_edge))
    elseif style != :default
        error("Unsupported ThermalHydrogenCCS balance style: $style")
    end

    return (; system, asset)
end

function assert_thermalhydrogenccs_solution(asset, model)
    expected_h2 = [1.0, 2.0, 3.0]
    expected_fuel = [2.0, 4.0, 6.0]
    expected_elec = [0.5, 1.0, 1.5]
    expected_co2 = [0.2, 0.4, 0.6]
    expected_co2_captured = [0.3, 0.6, 0.9]

    @test objective_value(model) ≈ 27.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.h2_edge, t)) ≈ expected_h2[t] atol = 1e-8
        @test value(flow(asset.fuel_edge, t)) ≈ expected_fuel[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
        @test value(flow(asset.co2_edge, t)) ≈ expected_co2[t] atol = 1e-8
        @test value(flow(asset.co2_captured_edge, t)) ≈ expected_co2_captured[t] atol = 1e-8
    end
end

function test_asset_thermalhydrogenccs_balance()
    @testset "ThermalHydrogenCCS Small Solve Cases" begin
        default_case = make_thermalhydrogenccs_case(:default)
        add_balance_case = make_thermalhydrogenccs_case(:add_balance)

        default_model = build_test_model(default_case.system)
        add_balance_model = build_test_model(add_balance_case.system)

        assert_thermalhydrogenccs_solution(default_case.asset, default_model)
        assert_thermalhydrogenccs_solution(add_balance_case.asset, add_balance_model)

        for t in 1:3
            @test value(flow(default_case.asset.h2_edge, t)) ≈ value(flow(add_balance_case.asset.h2_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.fuel_edge, t)) ≈ value(flow(add_balance_case.asset.fuel_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.elec_edge, t)) ≈ value(flow(add_balance_case.asset.elec_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.co2_edge, t)) ≈ value(flow(add_balance_case.asset.co2_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.co2_captured_edge, t)) ≈ value(flow(add_balance_case.asset.co2_captured_edge, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(add_balance_model) atol = 1e-8
    end

    return nothing
end

test_asset_thermalhydrogenccs_balance()

end # module TestAssetThermalHydrogenCCSBalance
