module TestAssetDownstreamEmissionsBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    CO2,
    DownstreamEmissions,
    NaturalGas,
    flow,
    make

function make_downstreamemissions_case(style::Symbol)
    system = make_test_system([NaturalGas, CO2])

    fuel_source = make_supply_node(NaturalGas, :fuel_source, system.time_data[:NaturalGas], [2.0, 2.0, 2.0])
    demand_sink = make_demand_node(NaturalGas, :demand_sink, system.time_data[:NaturalGas], [1.0, 2.0, 3.0])
    co2_sink = make_free_node(CO2, :co2_sink, system.time_data[:CO2])
    push_locations!(system, fuel_source, demand_sink, co2_sink)

    asset = make(
        DownstreamEmissions,
        Dict{Symbol,Any}(
            :id => :downstream_emissions_test,
            :timedata => "NaturalGas",
            :fuel_commodity => "NaturalGas",
            :fuel_demand_commodity => "NaturalGas",
            :emission_rate => 0.1,
            :co2_sink => :co2_sink,
            :fuel_start_vertex => :fuel_source,
            :fuel_demand_end_vertex => :demand_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.fuelsenduse_transform
    if style == :add_balance
        transform.balance_data = Dict{Symbol,Any}()
        @add_balance(transform, :fuel_demand, flow(asset.fuel_demand_edge) == flow(asset.fuel_edge))
        @add_balance(transform, :emissions, 0.1 * flow(asset.fuel_edge) == flow(asset.co2_edge))
    elseif style != :default
        error("Unsupported DownstreamEmissions balance style: $style")
    end

    return (; system, asset)
end

function assert_downstreamemissions_solution(asset, model)
    expected_fuel = [1.0, 2.0, 3.0]
    expected_co2 = [0.1, 0.2, 0.3]

    @test objective_value(model) ≈ 12.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.fuel_edge, t)) ≈ expected_fuel[t] atol = 1e-8
        @test value(flow(asset.fuel_demand_edge, t)) ≈ expected_fuel[t] atol = 1e-8
        @test value(flow(asset.co2_edge, t)) ≈ expected_co2[t] atol = 1e-8
    end
end

function test_asset_downstreamemissions_balance()
    @testset "DownstreamEmissions Small Solve Cases" begin
        default_case = make_downstreamemissions_case(:default)
        add_balance_case = make_downstreamemissions_case(:add_balance)

        default_model = build_test_model(default_case.system)
        add_balance_model = build_test_model(add_balance_case.system)

        assert_downstreamemissions_solution(default_case.asset, default_model)
        assert_downstreamemissions_solution(add_balance_case.asset, add_balance_model)

        for t in 1:3
            @test value(flow(default_case.asset.fuel_edge, t)) ≈ value(flow(add_balance_case.asset.fuel_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.fuel_demand_edge, t)) ≈ value(flow(add_balance_case.asset.fuel_demand_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.co2_edge, t)) ≈ value(flow(add_balance_case.asset.co2_edge, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(add_balance_model) atol = 1e-8
    end

    return nothing
end

test_asset_downstreamemissions_balance()

end # module TestAssetDownstreamEmissionsBalance
