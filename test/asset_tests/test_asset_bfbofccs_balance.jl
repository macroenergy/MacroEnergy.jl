module TestAssetBlastFurnaceBasicOxygenFurnaceCCSBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    @add_stoichiometric_balance,
    BlastFurnaceBasicOxygenFurnaceCCS,
    CO2,
    CO2Captured,
    Coal,
    CrudeSteel,
    Electricity,
    IronOre,
    NaturalGas,
    SteelScrap,
    flow,
    make

function make_bfbofccs_case(style::Symbol)
    system = make_test_system([IronOre, SteelScrap, Coal, NaturalGas, CrudeSteel, Electricity, CO2, CO2Captured])

    ironore_source = make_supply_node(IronOre, :ironore_source, system.time_data[:IronOre], [2.0, 2.0, 2.0])
    steelscrap_source = make_supply_node(SteelScrap, :steelscrap_source, system.time_data[:SteelScrap], [3.0, 3.0, 3.0])
    metcoal_source = make_supply_node(Coal, :metcoal_source, system.time_data[:Coal], [4.0, 4.0, 4.0])
    thermalcoal_source = make_supply_node(Coal, :thermalcoal_source, system.time_data[:Coal], [5.0, 5.0, 5.0])
    natgas_source = make_supply_node(NaturalGas, :natgas_source, system.time_data[:NaturalGas], [6.0, 6.0, 6.0])
    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    crudesteel_sink = make_demand_node(CrudeSteel, :crudesteel_sink, system.time_data[:CrudeSteel], [1.0, 2.0, 3.0])
    co2_sink = make_free_node(CO2, :co2_sink, system.time_data[:CO2])
    co2_captured_sink = make_free_node(CO2Captured, :co2_captured_sink, system.time_data[:CO2Captured])
    push_locations!(
        system,
        ironore_source,
        steelscrap_source,
        metcoal_source,
        thermalcoal_source,
        natgas_source,
        elec_source,
        crudesteel_sink,
        co2_sink,
        co2_captured_sink,
    )

    asset = make(
        BlastFurnaceBasicOxygenFurnaceCCS,
        Dict{Symbol,Any}(
            :id => :bfbofccs_test,
            :timedata => "CrudeSteel",
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 10.0,
            :ironore_consumption => 1.0,
            :steelscrap_consumption => 0.2,
            :metcoal_consumption => 0.3,
            :thermalcoal_consumption => 0.4,
            :natgas_consumption => 0.5,
            :electricity_consumption => 0.6,
            :emission_rate => 0.15,
            :capture_rate => 0.25,
            :co2_sink => :co2_sink,
            :co2_captured_end_vertex => :co2_captured_sink,
            :ironore_start_vertex => :ironore_source,
            :steelscrap_start_vertex => :steelscrap_source,
            :metcoal_start_vertex => :metcoal_source,
            :thermalcoal_start_vertex => :thermalcoal_source,
            :natgas_start_vertex => :natgas_source,
            :elec_start_vertex => :elec_source,
            :crudesteel_end_vertex => :crudesteel_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.bfbofccs_transform
    transform.balance_data = Dict{Symbol,Any}()

    if style == :add_balance
        @add_balance(transform, :ironore, 1.0 * flow(asset.crudesteel_edge) == flow(asset.ironore_edge))
        @add_balance(transform, :steelscrap, 0.2 * flow(asset.crudesteel_edge) == flow(asset.steelscrap_edge))
        @add_balance(transform, :metcoal, 0.3 * flow(asset.crudesteel_edge) == flow(asset.metcoal_edge))
        @add_balance(transform, :thermalcoal, 0.4 * flow(asset.crudesteel_edge) == flow(asset.thermalcoal_edge))
        @add_balance(transform, :natgas, 0.5 * flow(asset.crudesteel_edge) == flow(asset.natgas_edge))
        @add_balance(transform, :electricity, 0.6 * flow(asset.crudesteel_edge) == flow(asset.elec_edge))
        @add_balance(transform, :emissions, 0.15 * flow(asset.crudesteel_edge) == flow(asset.co2_edge))
        @add_balance(transform, :capture, 0.25 * flow(asset.crudesteel_edge) == flow(asset.co2_captured_edge))
    elseif style == :stoich
        @add_stoichiometric_balance(
            transform,
            :steel_production,
            1.0 * flow(asset.ironore_edge)
            + 0.2 * flow(asset.steelscrap_edge)
            + 0.3 * flow(asset.metcoal_edge)
            + 0.4 * flow(asset.thermalcoal_edge)
            + 0.5 * flow(asset.natgas_edge)
            + 0.6 * flow(asset.elec_edge)
            -->
            flow(asset.crudesteel_edge)
            + 0.15 * flow(asset.co2_edge)
            + 0.25 * flow(asset.co2_captured_edge),
            flow(asset.crudesteel_edge),
        )
    else
        error("Unsupported BFBof CCS balance style: $style")
    end

    return (; system, asset)
end

function assert_bfbofccs_solution(asset, model)
    expected_crudesteel = [1.0, 2.0, 3.0]
    expected_ironore = [1.0, 2.0, 3.0]
    expected_steelscrap = [0.2, 0.4, 0.6]
    expected_metcoal = [0.3, 0.6, 0.9]
    expected_thermalcoal = [0.4, 0.8, 1.2]
    expected_natgas = [0.5, 1.0, 1.5]
    expected_elec = [0.6, 1.2, 1.8]
    expected_co2 = [0.15, 0.3, 0.45]
    expected_co2_captured = [0.25, 0.5, 0.75]

    @test objective_value(model) ≈ 56.4 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.crudesteel_edge, t)) ≈ expected_crudesteel[t] atol = 1e-8
        @test value(flow(asset.ironore_edge, t)) ≈ expected_ironore[t] atol = 1e-8
        @test value(flow(asset.steelscrap_edge, t)) ≈ expected_steelscrap[t] atol = 1e-8
        @test value(flow(asset.metcoal_edge, t)) ≈ expected_metcoal[t] atol = 1e-8
        @test value(flow(asset.thermalcoal_edge, t)) ≈ expected_thermalcoal[t] atol = 1e-8
        @test value(flow(asset.natgas_edge, t)) ≈ expected_natgas[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
        @test value(flow(asset.co2_edge, t)) ≈ expected_co2[t] atol = 1e-8
        @test value(flow(asset.co2_captured_edge, t)) ≈ expected_co2_captured[t] atol = 1e-8
    end
end

function test_asset_bfbofccs_balance()
    @testset "BlastFurnaceBasicOxygenFurnaceCCS Small Solve Cases" begin
        add_balance_case = make_bfbofccs_case(:add_balance)
        stoich_case = make_bfbofccs_case(:stoich)

        add_balance_model = build_test_model(add_balance_case.system)
        stoich_model = build_test_model(stoich_case.system)

        assert_bfbofccs_solution(add_balance_case.asset, add_balance_model)
        assert_bfbofccs_solution(stoich_case.asset, stoich_model)

        for t in 1:3
            @test value(flow(add_balance_case.asset.crudesteel_edge, t)) ≈ value(flow(stoich_case.asset.crudesteel_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.ironore_edge, t)) ≈ value(flow(stoich_case.asset.ironore_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.steelscrap_edge, t)) ≈ value(flow(stoich_case.asset.steelscrap_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.metcoal_edge, t)) ≈ value(flow(stoich_case.asset.metcoal_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.thermalcoal_edge, t)) ≈ value(flow(stoich_case.asset.thermalcoal_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.natgas_edge, t)) ≈ value(flow(stoich_case.asset.natgas_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.elec_edge, t)) ≈ value(flow(stoich_case.asset.elec_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.co2_edge, t)) ≈ value(flow(stoich_case.asset.co2_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.co2_captured_edge, t)) ≈ value(flow(stoich_case.asset.co2_captured_edge, t)) atol = 1e-8
        end
        @test objective_value(add_balance_model) ≈ objective_value(stoich_model) atol = 1e-8
    end

    return nothing
end

test_asset_bfbofccs_balance()

end # module TestAssetBlastFurnaceBasicOxygenFurnaceCCSBalance
