module TestAssetThermalHeatingBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    CO2,
    Heat,
    NaturalGas,
    ThermalHeating,
    flow,
    make

function make_thermalheating_case(style::Symbol)
    system = make_test_system([Heat, NaturalGas, CO2])

    fuel_source = make_supply_node(NaturalGas, :fuel_source, system.time_data[:NaturalGas], [2.0, 2.0, 2.0])
    heat_sink = make_demand_node(Heat, :heat_sink, system.time_data[:Heat], [10.0, 20.0, 30.0])
    co2_sink = make_free_node(CO2, :co2_sink, system.time_data[:CO2])
    push_locations!(system, fuel_source, heat_sink, co2_sink)

    asset = make(
        ThermalHeating,
        Dict{Symbol,Any}(
            :id => :thermal_heating_test,
            :timedata => "Heat",
            :fuel_commodity => "NaturalGas",
            :co2_sink => :co2_sink,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 100.0,
            :fuel_consumption => 2.0,
            :emission_rate => 0.1,
            :fuel_start_vertex => :fuel_source,
            :heat_end_vertex => :heat_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.heating_transform
    if style == :add_balance
        transform.balance_data = Dict{Symbol,Any}()
        @add_balance(transform, :energy, 2.0 * flow(asset.heat_edge) == flow(asset.fuel_edge))
        @add_balance(transform, :emissions, 0.1 * flow(asset.fuel_edge) == flow(asset.co2_edge))
    elseif style != :default
        error("Unsupported ThermalHeating balance style: $style")
    end

    return (; system, asset)
end

function assert_thermalheating_solution(asset, model)
    expected_heat = [10.0, 20.0, 30.0]
    expected_fuel = [20.0, 40.0, 60.0]
    expected_co2 = [2.0, 4.0, 6.0]

    @test objective_value(model) ≈ 240.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.heat_edge, t)) ≈ expected_heat[t] atol = 1e-8
        @test value(flow(asset.fuel_edge, t)) ≈ expected_fuel[t] atol = 1e-8
        @test value(flow(asset.co2_edge, t)) ≈ expected_co2[t] atol = 1e-8
    end
end

function test_asset_thermalheating_balance()
    @testset "ThermalHeating Small Solve Cases" begin
        default_case = make_thermalheating_case(:default)
        add_balance_case = make_thermalheating_case(:add_balance)

        default_model = build_test_model(default_case.system)
        add_balance_model = build_test_model(add_balance_case.system)

        assert_thermalheating_solution(default_case.asset, default_model)
        assert_thermalheating_solution(add_balance_case.asset, add_balance_model)

        for t in 1:3
            @test value(flow(default_case.asset.heat_edge, t)) ≈ value(flow(add_balance_case.asset.heat_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.fuel_edge, t)) ≈ value(flow(add_balance_case.asset.fuel_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.co2_edge, t)) ≈ value(flow(add_balance_case.asset.co2_edge, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(add_balance_model) atol = 1e-8
    end

    return nothing
end

test_asset_thermalheating_balance()

end # module TestAssetThermalHeatingBalance
