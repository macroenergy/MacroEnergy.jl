module TestAssetUpstreamEmissionsBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    CO2,
    NaturalGas,
    UpstreamEmissions,
    flow,
    make

function make_upstreamemissions_case(style::Symbol)
    system = make_test_system([NaturalGas, CO2])

    fossil_source = make_supply_node(NaturalGas, :fossil_source, system.time_data[:NaturalGas], [2.0, 2.0, 2.0])
    fuel_sink = make_demand_node(NaturalGas, :fuel_sink, system.time_data[:NaturalGas], [1.0, 2.0, 3.0])
    co2_sink = make_free_node(CO2, :co2_sink, system.time_data[:CO2])
    push_locations!(system, fossil_source, fuel_sink, co2_sink)

    asset = make(
        UpstreamEmissions,
        Dict{Symbol,Any}(
            :id => :upstream_emissions_test,
            :timedata => "NaturalGas",
            :fuel_commodity => "NaturalGas",
            :fossil_fuel_commodity => "NaturalGas",
            :emission_rate => 0.1,
            :co2_sink => :co2_sink,
            :fossil_fuel_start_vertex => :fossil_source,
            :fuel_end_vertex => :fuel_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.fossilfuelsupstream_transform
    if style == :add_balance
        transform.balance_data = Dict{Symbol,Any}()
        @add_balance(transform, :fuel, flow(asset.fuel_edge) == flow(asset.fossil_fuel_edge))
        @add_balance(transform, :emissions, 0.1 * flow(asset.fossil_fuel_edge) == flow(asset.co2_edge))
    elseif style != :default
        error("Unsupported UpstreamEmissions balance style: $style")
    end

    return (; system, asset)
end

function assert_upstreamemissions_solution(asset, model)
    expected_fuel = [1.0, 2.0, 3.0]
    expected_co2 = [0.1, 0.2, 0.3]

    @test objective_value(model) ≈ 12.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.fossil_fuel_edge, t)) ≈ expected_fuel[t] atol = 1e-8
        @test value(flow(asset.fuel_edge, t)) ≈ expected_fuel[t] atol = 1e-8
        @test value(flow(asset.co2_edge, t)) ≈ expected_co2[t] atol = 1e-8
    end
end

function test_asset_upstreamemissions_balance()
    @testset "UpstreamEmissions Small Solve Cases" begin
        default_case = make_upstreamemissions_case(:default)
        add_balance_case = make_upstreamemissions_case(:add_balance)

        default_model = build_test_model(default_case.system)
        add_balance_model = build_test_model(add_balance_case.system)

        assert_upstreamemissions_solution(default_case.asset, default_model)
        assert_upstreamemissions_solution(add_balance_case.asset, add_balance_model)

        for t in 1:3
            @test value(flow(default_case.asset.fossil_fuel_edge, t)) ≈ value(flow(add_balance_case.asset.fossil_fuel_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.fuel_edge, t)) ≈ value(flow(add_balance_case.asset.fuel_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.co2_edge, t)) ≈ value(flow(add_balance_case.asset.co2_edge, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(add_balance_model) atol = 1e-8
    end

    return nothing
end

test_asset_upstreamemissions_balance()

end # module TestAssetUpstreamEmissionsBalance
