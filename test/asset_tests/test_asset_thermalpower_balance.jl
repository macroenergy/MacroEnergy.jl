module TestAssetThermalPowerBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    @add_stoichiometric_balance,
    CO2,
    Electricity,
    NaturalGas,
    ThermalPower,
    flow,
    make

function make_thermalpower_case(style::Symbol)
    system = make_test_system([Electricity, NaturalGas, CO2])
    fuel_timedata = system.time_data[:NaturalGas]
    elec_timedata = system.time_data[:Electricity]
    co2_timedata = system.time_data[:CO2]

    fuel_source = make_supply_node(NaturalGas, :fuel_source, fuel_timedata, [2.0, 2.0, 2.0])
    elec_sink = make_demand_node(Electricity, :elec_sink, elec_timedata, [10.0, 20.0, 30.0])
    co2_sink = make_free_node(CO2, :co2_sink, co2_timedata)
    push_locations!(system, fuel_source, elec_sink, co2_sink)

    asset = make(
        ThermalPower,
        Dict{Symbol,Any}(
            :id => :thermal_power_test,
            :timedata => "Electricity",
            :fuel_commodity => "NaturalGas",
            :co2_sink => :co2_sink,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 100.0,
            :fuel_consumption => 2.0,
            :emission_rate => 0.1,
            :fuel_start_vertex => :fuel_source,
            :elec_end_vertex => :elec_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.thermal_transform
    transform.balance_data = Dict{Symbol,Any}()

    if style == :add_balance
        @add_balance(transform, :energy, 2.0 * flow(asset.elec_edge) == flow(asset.fuel_edge))
        @add_balance(transform, :emissions, 0.1 * flow(asset.fuel_edge) == flow(asset.co2_edge))
    elseif style == :stoich
        @add_stoichiometric_balance(
            transform,
            :thermal_power,
            flow(asset.fuel_edge) --> 0.5 * flow(asset.elec_edge) + 0.1 * flow(asset.co2_edge),
            flow(asset.fuel_edge),
        )
    else
        error("Unsupported thermal power balance style: $style")
    end

    return (; system, asset)
end

function assert_thermalpower_solution(asset, model)
    expected_elec = [10.0, 20.0, 30.0]
    expected_fuel = [20.0, 40.0, 60.0]
    expected_co2 = [2.0, 4.0, 6.0]

    @test objective_value(model) ≈ 240.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
        @test value(flow(asset.fuel_edge, t)) ≈ expected_fuel[t] atol = 1e-8
        @test value(flow(asset.co2_edge, t)) ≈ expected_co2[t] atol = 1e-8
    end
end

function test_asset_thermalpower_balance()
    @testset "ThermalPower Small Solve Cases" begin
        add_balance_case = make_thermalpower_case(:add_balance)
        stoich_case = make_thermalpower_case(:stoich)

        add_balance_model = build_test_model(add_balance_case.system)
        stoich_model = build_test_model(stoich_case.system)

        assert_thermalpower_solution(add_balance_case.asset, add_balance_model)
        assert_thermalpower_solution(stoich_case.asset, stoich_model)

        for t in 1:3
            @test value(flow(add_balance_case.asset.elec_edge, t)) ≈ value(flow(stoich_case.asset.elec_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.fuel_edge, t)) ≈ value(flow(stoich_case.asset.fuel_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.co2_edge, t)) ≈ value(flow(stoich_case.asset.co2_edge, t)) atol = 1e-8
        end
        @test objective_value(add_balance_model) ≈ objective_value(stoich_model) atol = 1e-8
    end

    return nothing
end

test_asset_thermalpower_balance()

end # module TestAssetThermalPowerBalance
