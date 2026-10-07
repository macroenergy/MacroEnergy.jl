module TestAssetConstrainedFossilLiquidFuelsBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    CO2,
    ConstrainedFossilLiquidFuels,
    LiquidFuels,
    flow,
    make

function test_asset_constrainedfossilliquidfuels_balance()
    @testset "ConstrainedFossilLiquidFuels Small Solve Case" begin
        system = make_test_system([LiquidFuels, CO2])
        fuel_timedata = system.time_data[:LiquidFuels]

        fossil_gasoline_source = make_supply_node(LiquidFuels, :fossil_gasoline_source, fuel_timedata, [1.0, 1.0, 1.0])
        fossil_jetfuel_source = make_supply_node(LiquidFuels, :fossil_jetfuel_source, fuel_timedata, [2.0, 2.0, 2.0])
        fossil_diesel_source = make_supply_node(LiquidFuels, :fossil_diesel_source, fuel_timedata, [3.0, 3.0, 3.0])
        gasoline_sink = make_demand_node(LiquidFuels, :gasoline_sink, fuel_timedata, [10.0, 10.0, 10.0])
        jetfuel_sink = make_free_node(LiquidFuels, :jetfuel_sink, fuel_timedata)
        diesel_sink = make_free_node(LiquidFuels, :diesel_sink, fuel_timedata)
        co2_sink = make_free_node(CO2, :co2_sink, system.time_data[:CO2])
        push_locations!(system, fossil_gasoline_source, fossil_jetfuel_source, fossil_diesel_source, gasoline_sink, jetfuel_sink, diesel_sink, co2_sink)

        asset = make(
            ConstrainedFossilLiquidFuels,
            Dict{Symbol,Any}(
                :id => :constrained_fossil_liquid_fuels_test,
                :timedata => "LiquidFuels",
                :fossil_gasoline_commodity => "LiquidFuels",
                :fossil_jetfuel_commodity => "LiquidFuels",
                :fossil_diesel_commodity => "LiquidFuels",
                :gasoline_commodity => "LiquidFuels",
                :jetfuel_commodity => "LiquidFuels",
                :diesel_commodity => "LiquidFuels",
                :jetfuel_ratio => 0.5,
                :diesel_ratio => 0.2,
                :gasoline_emission_rate => 0.1,
                :jetfuel_emission_rate => 0.2,
                :diesel_emission_rate => 0.3,
                :fossil_gasoline_start_vertex => :fossil_gasoline_source,
                :fossil_jetfuel_start_vertex => :fossil_jetfuel_source,
                :fossil_diesel_start_vertex => :fossil_diesel_source,
                :gasoline_end_vertex => :gasoline_sink,
                :jetfuel_end_vertex => :jetfuel_sink,
                :diesel_end_vertex => :diesel_sink,
                :co2_sink => :co2_sink,
            ),
            system,
        )
        push!(system.assets, asset)

        model = build_test_model(system)
        @test objective_value(model) ≈ 78.0 atol = 1e-8
        for t in 1:3
            @test value(flow(asset.gasoline_edge, t)) ≈ 10.0 atol = 1e-8
            @test value(flow(asset.jetfuel_edge, t)) ≈ 5.0 atol = 1e-8
            @test value(flow(asset.diesel_edge, t)) ≈ 2.0 atol = 1e-8
            @test value(flow(asset.co2_edge, t)) ≈ 2.6 atol = 1e-8
        end
    end

    return nothing
end

test_asset_constrainedfossilliquidfuels_balance()

end # module TestAssetConstrainedFossilLiquidFuelsBalance
