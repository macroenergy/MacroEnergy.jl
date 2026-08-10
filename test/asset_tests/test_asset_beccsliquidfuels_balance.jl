module TestAssetBECCSLiquidFuelsBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    @add_stoichiometric_balance,
    BECCSLiquidFuels,
    Biomass,
    CO2,
    CO2Captured,
    Electricity,
    LiquidFuels,
    flow,
    make

function make_beccsliquidfuels_case(style::Symbol)
    system = make_test_system([Biomass, Electricity, CO2, CO2Captured, LiquidFuels])

    biomass_source = make_supply_node(Biomass, :biomass_source, system.time_data[:Biomass], [4.0, 4.0, 4.0])
    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    co2_source = make_supply_node(CO2, :co2_source, system.time_data[:CO2], [1.0, 1.0, 1.0])
    gasoline_sink = make_demand_node(LiquidFuels, :gasoline_sink, system.time_data[:LiquidFuels], [1.0, 2.0, 3.0])
    jetfuel_sink = make_free_node(LiquidFuels, :jetfuel_sink, system.time_data[:LiquidFuels])
    diesel_sink = make_free_node(LiquidFuels, :diesel_sink, system.time_data[:LiquidFuels])
    elec_product_sink = make_free_node(Electricity, :elec_product_sink, system.time_data[:Electricity])
    co2_emission_sink = make_free_node(CO2, :co2_emission_sink, system.time_data[:CO2])
    co2_captured_sink = make_free_node(CO2Captured, :co2_captured_sink, system.time_data[:CO2Captured])
    push_locations!(system, biomass_source, elec_source, co2_source, gasoline_sink, jetfuel_sink, diesel_sink, elec_product_sink, co2_emission_sink, co2_captured_sink)

    asset = make(
        BECCSLiquidFuels,
        Dict{Symbol,Any}(
            :id => :beccs_liquid_fuels_test,
            :timedata => "Biomass",
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 100.0,
            :gasoline_production => 0.2,
            :jetfuel_production => 0.1,
            :diesel_production => 0.15,
            :electricity_consumption => 0.1,
            :electricity_production => 0.05,
            :co2_content => 0.1,
            :emission_rate => 0.15,
            :capture_rate => 0.25,
            :biomass_start_vertex => :biomass_source,
            :elec_consumption_start_vertex => :elec_source,
            :co2_start_vertex => :co2_source,
            :gasoline_end_vertex => :gasoline_sink,
            :jetfuel_end_vertex => :jetfuel_sink,
            :diesel_end_vertex => :diesel_sink,
            :elec_production_end_vertex => :elec_product_sink,
            :co2_emission_end_vertex => :co2_emission_sink,
            :co2_captured_end_vertex => :co2_captured_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.beccs_transform
    transform.balance_data = Dict{Symbol,Any}()

    if style == :add_balance
        @add_balance(transform, :gasoline, 0.2 * flow(asset.biomass_edge) == flow(asset.gasoline_edge))
        @add_balance(transform, :jetfuel, 0.1 * flow(asset.biomass_edge) == flow(asset.jetfuel_edge))
        @add_balance(transform, :diesel, 0.15 * flow(asset.biomass_edge) == flow(asset.diesel_edge))
        @add_balance(transform, :electricity_consumption, 0.1 * flow(asset.biomass_edge) == flow(asset.elec_consumption_edge))
        @add_balance(transform, :electricity_production, 0.05 * flow(asset.biomass_edge) == flow(asset.elec_production_edge))
        @add_balance(transform, :co2_content, 0.1 * flow(asset.biomass_edge) == flow(asset.co2_edge))
        @add_balance(transform, :emissions, 0.15 * flow(asset.biomass_edge) == flow(asset.co2_emission_edge))
        @add_balance(transform, :capture, 0.25 * flow(asset.biomass_edge) == flow(asset.co2_captured_edge))
    elseif style == :stoich
        @add_stoichiometric_balance(
            transform,
            :beccs_liquid_fuels,
            flow(asset.biomass_edge) + 0.1 * flow(asset.elec_consumption_edge) + 0.1 * flow(asset.co2_edge)
            -->
            0.2 * flow(asset.gasoline_edge)
            + 0.1 * flow(asset.jetfuel_edge)
            + 0.15 * flow(asset.diesel_edge)
            + 0.05 * flow(asset.elec_production_edge)
            + 0.15 * flow(asset.co2_emission_edge)
            + 0.25 * flow(asset.co2_captured_edge),
            flow(asset.biomass_edge),
        )
    else
        error("Unsupported BECCSLiquidFuels balance style: $style")
    end

    return (; system, asset)
end

function assert_beccsliquidfuels_solution(asset, model)
    expected_biomass = [5.0, 10.0, 15.0]
    expected_gasoline = [1.0, 2.0, 3.0]
    expected_jetfuel = [0.5, 1.0, 1.5]
    expected_diesel = [0.75, 1.5, 2.25]
    expected_elec_consumption = [0.5, 1.0, 1.5]
    expected_elec_production = [0.25, 0.5, 0.75]
    expected_co2 = [0.5, 1.0, 1.5]
    expected_co2_emission = [0.75, 1.5, 2.25]
    expected_co2_captured = [1.25, 2.5, 3.75]

    @test objective_value(model) ≈ 126.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.biomass_edge, t)) ≈ expected_biomass[t] atol = 1e-8
        @test value(flow(asset.gasoline_edge, t)) ≈ expected_gasoline[t] atol = 1e-8
        @test value(flow(asset.jetfuel_edge, t)) ≈ expected_jetfuel[t] atol = 1e-8
        @test value(flow(asset.diesel_edge, t)) ≈ expected_diesel[t] atol = 1e-8
        @test value(flow(asset.elec_consumption_edge, t)) ≈ expected_elec_consumption[t] atol = 1e-8
        @test value(flow(asset.elec_production_edge, t)) ≈ expected_elec_production[t] atol = 1e-8
        @test value(flow(asset.co2_edge, t)) ≈ expected_co2[t] atol = 1e-8
        @test value(flow(asset.co2_emission_edge, t)) ≈ expected_co2_emission[t] atol = 1e-8
        @test value(flow(asset.co2_captured_edge, t)) ≈ expected_co2_captured[t] atol = 1e-8
    end
end

function test_asset_beccsliquidfuels_balance()
    @testset "BECCSLiquidFuels Small Solve Cases" begin
        add_balance_case = make_beccsliquidfuels_case(:add_balance)
        stoich_case = make_beccsliquidfuels_case(:stoich)

        add_balance_model = build_test_model(add_balance_case.system)
        stoich_model = build_test_model(stoich_case.system)

        assert_beccsliquidfuels_solution(add_balance_case.asset, add_balance_model)
        assert_beccsliquidfuels_solution(stoich_case.asset, stoich_model)

        for t in 1:3
            @test value(flow(add_balance_case.asset.biomass_edge, t)) ≈ value(flow(stoich_case.asset.biomass_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.gasoline_edge, t)) ≈ value(flow(stoich_case.asset.gasoline_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.jetfuel_edge, t)) ≈ value(flow(stoich_case.asset.jetfuel_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.diesel_edge, t)) ≈ value(flow(stoich_case.asset.diesel_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.elec_consumption_edge, t)) ≈ value(flow(stoich_case.asset.elec_consumption_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.elec_production_edge, t)) ≈ value(flow(stoich_case.asset.elec_production_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.co2_edge, t)) ≈ value(flow(stoich_case.asset.co2_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.co2_emission_edge, t)) ≈ value(flow(stoich_case.asset.co2_emission_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.co2_captured_edge, t)) ≈ value(flow(stoich_case.asset.co2_captured_edge, t)) atol = 1e-8
        end
        @test objective_value(add_balance_model) ≈ objective_value(stoich_model) atol = 1e-8
    end

    return nothing
end

test_asset_beccsliquidfuels_balance()

end # module TestAssetBECCSLiquidFuelsBalance
