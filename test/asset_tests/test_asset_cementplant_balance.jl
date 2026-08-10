module TestAssetCementPlantBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    @add_stoichiometric_balance,
    CO2,
    CO2Captured,
    Cement,
    CementPlant,
    Electricity,
    NaturalGas,
    flow,
    make

function make_cementplant_case(style::Symbol)
    system = make_test_system([Electricity, NaturalGas, Cement, CO2, CO2Captured])

    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    fuel_source = make_supply_node(NaturalGas, :fuel_source, system.time_data[:NaturalGas], [2.0, 2.0, 2.0])
    cement_sink = make_demand_node(Cement, :cement_sink, system.time_data[:Cement], [1.0, 2.0, 3.0])
    co2_sink = make_free_node(CO2, :co2_sink, system.time_data[:CO2])
    co2_captured_sink = make_free_node(CO2Captured, :co2_captured_sink, system.time_data[:CO2Captured])
    push_locations!(system, elec_source, fuel_source, cement_sink, co2_sink, co2_captured_sink)

    asset = make(
        CementPlant,
        Dict{Symbol,Any}(
            :id => :cementplant_test,
            :timedata => "Cement",
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 10.0,
            :fuel_commodity => "NaturalGas",
            :elec_consumption_rate => 0.5,
            :fuel_consumption_rate => 1.0,
            :fuel_emission_rate => 0.1,
            :process_emission_rate => 0.2,
            :co2_capture_rate => 0.25,
            :co2_sink => :co2_sink,
            :co2_captured_end_vertex => :co2_captured_sink,
            :elec_start_vertex => :elec_source,
            :fuel_start_vertex => :fuel_source,
            :cement_end_vertex => :cement_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.cement_transform
    transform.balance_data = Dict{Symbol,Any}()

    if style == :add_balance
        @add_balance(transform, :electricity, 0.5 * flow(asset.cement_edge) == flow(asset.elec_edge))
        @add_balance(transform, :fuel, 1.0 * flow(asset.cement_edge) == flow(asset.fuel_edge))
        @add_balance(transform, :emissions, 0.225 * flow(asset.cement_edge) == flow(asset.co2_emissions_edge))
        @add_balance(transform, :capture, 0.075 * flow(asset.cement_edge) == flow(asset.co2_captured_edge))
    elseif style == :stoich
        @add_stoichiometric_balance(
            transform,
            :cement_production,
            0.5 * flow(asset.elec_edge) + 1.0 * flow(asset.fuel_edge)
            -->
            flow(asset.cement_edge) + 0.225 * flow(asset.co2_emissions_edge) + 0.075 * flow(asset.co2_captured_edge),
            flow(asset.cement_edge),
        )
    else
        error("Unsupported cement plant balance style: $style")
    end

    return (; system, asset)
end

function assert_cementplant_solution(asset, model)
    expected_cement = [1.0, 2.0, 3.0]
    expected_elec = [0.5, 1.0, 1.5]
    expected_fuel = [1.0, 2.0, 3.0]
    expected_co2 = [0.225, 0.45, 0.675]
    expected_co2_captured = [0.075, 0.15, 0.225]

    @test objective_value(model) ≈ 15.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.cement_edge, t)) ≈ expected_cement[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
        @test value(flow(asset.fuel_edge, t)) ≈ expected_fuel[t] atol = 1e-8
        @test value(flow(asset.co2_emissions_edge, t)) ≈ expected_co2[t] atol = 1e-8
        @test value(flow(asset.co2_captured_edge, t)) ≈ expected_co2_captured[t] atol = 1e-8
    end
end

function test_asset_cementplant_balance()
    @testset "CementPlant Small Solve Cases" begin
        add_balance_case = make_cementplant_case(:add_balance)
        stoich_case = make_cementplant_case(:stoich)

        add_balance_model = build_test_model(add_balance_case.system)
        stoich_model = build_test_model(stoich_case.system)

        assert_cementplant_solution(add_balance_case.asset, add_balance_model)
        assert_cementplant_solution(stoich_case.asset, stoich_model)

        for t in 1:3
            @test value(flow(add_balance_case.asset.cement_edge, t)) ≈ value(flow(stoich_case.asset.cement_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.elec_edge, t)) ≈ value(flow(stoich_case.asset.elec_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.fuel_edge, t)) ≈ value(flow(stoich_case.asset.fuel_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.co2_emissions_edge, t)) ≈ value(flow(stoich_case.asset.co2_emissions_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.co2_captured_edge, t)) ≈ value(flow(stoich_case.asset.co2_captured_edge, t)) atol = 1e-8
        end
        @test objective_value(add_balance_model) ≈ objective_value(stoich_model) atol = 1e-8
    end

    return nothing
end

test_asset_cementplant_balance()

end # module TestAssetCementPlantBalance
