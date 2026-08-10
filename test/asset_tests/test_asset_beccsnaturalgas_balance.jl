module TestAssetBECCSNaturalGasBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    @add_stoichiometric_balance,
    BECCSNaturalGas,
    Biomass,
    CO2,
    CO2Captured,
    Electricity,
    NaturalGas,
    flow,
    make

function make_beccsnaturalgas_case(style::Symbol)
    system = make_test_system([Biomass, Electricity, CO2, CO2Captured, NaturalGas])

    biomass_source = make_supply_node(Biomass, :biomass_source, system.time_data[:Biomass], [4.0, 4.0, 4.0])
    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    co2_source = make_supply_node(CO2, :co2_source, system.time_data[:CO2], [1.0, 1.0, 1.0])
    natgas_sink = make_demand_node(NaturalGas, :natgas_sink, system.time_data[:NaturalGas], [1.0, 2.0, 3.0])
    co2_emission_sink = make_free_node(CO2, :co2_emission_sink, system.time_data[:CO2])
    co2_captured_sink = make_free_node(CO2Captured, :co2_captured_sink, system.time_data[:CO2Captured])
    push_locations!(system, biomass_source, elec_source, co2_source, natgas_sink, co2_emission_sink, co2_captured_sink)

    asset = make(
        BECCSNaturalGas,
        Dict{Symbol,Any}(
            :id => :beccs_natural_gas_test,
            :timedata => "Biomass",
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 100.0,
            :natgas_production => 0.5,
            :electricity_consumption => 0.2,
            :co2_content => 0.1,
            :emission_rate => 0.15,
            :capture_rate => 0.25,
            :biomass_start_vertex => :biomass_source,
            :elec_start_vertex => :elec_source,
            :co2_start_vertex => :co2_source,
            :natgas_end_vertex => :natgas_sink,
            :co2_emission_end_vertex => :co2_emission_sink,
            :co2_captured_end_vertex => :co2_captured_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.beccs_transform
    transform.balance_data = Dict{Symbol,Any}()

    if style == :add_balance
        @add_balance(transform, :natural_gas, 0.5 * flow(asset.biomass_edge) == flow(asset.natgas_edge))
        @add_balance(transform, :electricity, 0.2 * flow(asset.biomass_edge) == flow(asset.elec_edge))
        @add_balance(transform, :co2_content, 0.1 * flow(asset.biomass_edge) == flow(asset.co2_edge))
        @add_balance(transform, :emissions, 0.15 * flow(asset.biomass_edge) == flow(asset.co2_emission_edge))
        @add_balance(transform, :capture, 0.25 * flow(asset.biomass_edge) == flow(asset.co2_captured_edge))
    elseif style == :stoich
        @add_stoichiometric_balance(
            transform,
            :beccs_natural_gas,
            flow(asset.biomass_edge) + 0.2 * flow(asset.elec_edge) + 0.1 * flow(asset.co2_edge)
            -->
            0.5 * flow(asset.natgas_edge) + 0.15 * flow(asset.co2_emission_edge) + 0.25 * flow(asset.co2_captured_edge),
            flow(asset.biomass_edge),
        )
    else
        error("Unsupported BECCSNaturalGas balance style: $style")
    end

    return (; system, asset)
end

function assert_beccsnaturalgas_solution(asset, model)
    expected_natgas = [1.0, 2.0, 3.0]
    expected_biomass = [2.0, 4.0, 6.0]
    expected_elec = [0.4, 0.8, 1.2]
    expected_co2 = [0.2, 0.4, 0.6]
    expected_co2_emission = [0.3, 0.6, 0.9]
    expected_co2_captured = [0.5, 1.0, 1.5]

    @test objective_value(model) ≈ 51.6 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.natgas_edge, t)) ≈ expected_natgas[t] atol = 1e-8
        @test value(flow(asset.biomass_edge, t)) ≈ expected_biomass[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
        @test value(flow(asset.co2_edge, t)) ≈ expected_co2[t] atol = 1e-8
        @test value(flow(asset.co2_emission_edge, t)) ≈ expected_co2_emission[t] atol = 1e-8
        @test value(flow(asset.co2_captured_edge, t)) ≈ expected_co2_captured[t] atol = 1e-8
    end
end

function test_asset_beccsnaturalgas_balance()
    @testset "BECCSNaturalGas Small Solve Cases" begin
        add_balance_case = make_beccsnaturalgas_case(:add_balance)
        stoich_case = make_beccsnaturalgas_case(:stoich)

        add_balance_model = build_test_model(add_balance_case.system)
        stoich_model = build_test_model(stoich_case.system)

        assert_beccsnaturalgas_solution(add_balance_case.asset, add_balance_model)
        assert_beccsnaturalgas_solution(stoich_case.asset, stoich_model)

        for t in 1:3
            @test value(flow(add_balance_case.asset.natgas_edge, t)) ≈ value(flow(stoich_case.asset.natgas_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.biomass_edge, t)) ≈ value(flow(stoich_case.asset.biomass_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.elec_edge, t)) ≈ value(flow(stoich_case.asset.elec_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.co2_edge, t)) ≈ value(flow(stoich_case.asset.co2_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.co2_emission_edge, t)) ≈ value(flow(stoich_case.asset.co2_emission_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.co2_captured_edge, t)) ≈ value(flow(stoich_case.asset.co2_captured_edge, t)) atol = 1e-8
        end
        @test objective_value(add_balance_model) ≈ objective_value(stoich_model) atol = 1e-8
    end

    return nothing
end

test_asset_beccsnaturalgas_balance()

end # module TestAssetBECCSNaturalGasBalance
