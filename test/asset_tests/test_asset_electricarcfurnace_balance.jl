module TestAssetElectricArcFurnaceBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    @add_stoichiometric_balance,
    CO2,
    Coal,
    CrudeSteel,
    ElectricArcFurnace,
    Electricity,
    NaturalGas,
    SteelScrap,
    flow,
    make

function make_eaf_case(style::Symbol)
    system = make_test_system([SteelScrap, Electricity, NaturalGas, Coal, CrudeSteel, CO2])

    scrap_source = make_supply_node(SteelScrap, :scrap_source, system.time_data[:SteelScrap], [2.0, 2.0, 2.0])
    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    naturalgas_source = make_supply_node(NaturalGas, :naturalgas_source, system.time_data[:NaturalGas], [3.0, 3.0, 3.0])
    carbonsource_source = make_supply_node(Coal, :carbonsource_source, system.time_data[:Coal], [4.0, 4.0, 4.0])
    crudesteel_sink = make_demand_node(CrudeSteel, :crudesteel_sink, system.time_data[:CrudeSteel], [1.0, 2.0, 3.0])
    co2_sink = make_free_node(CO2, :co2_sink, system.time_data[:CO2])
    push_locations!(system, scrap_source, elec_source, naturalgas_source, carbonsource_source, crudesteel_sink, co2_sink)

    asset = make(
        ElectricArcFurnace,
        Dict{Symbol,Any}(
            :id => :eaf_test,
            :transforms => Dict{Symbol,Any}(
                :timedata => "CrudeSteel",
                :electricity_consumption => 0.5,
                :steelscrap_consumption => 1.1,
                :naturalgas_consumption => 0.2,
                :carbonsource_consumption => 0.1,
                :emission_rate => 0.3,
            ),
            :edges => Dict{Symbol,Any}(
                :carbonsource_edge => Dict{Symbol,Any}(:commodity => "Coal"),
                :crudesteel_edge => Dict{Symbol,Any}(
                    :can_expand => false,
                    :can_retire => false,
                    :existing_capacity => 10.0,
                ),
            ),
            :co2_sink => :co2_sink,
            :elec_start_vertex => :elec_source,
            :steelscrap_start_vertex => :scrap_source,
            :naturalgas_start_vertex => :naturalgas_source,
            :carbonsource_start_vertex => :carbonsource_source,
            :crudesteel_end_vertex => :crudesteel_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.eaf_transform
    transform.balance_data = Dict{Symbol,Any}()

    if style == :add_balance
        @add_balance(transform, :electricity, 0.5 * flow(asset.crudesteel_edge) == flow(asset.elec_edge))
        @add_balance(transform, :steelscrap, 1.1 * flow(asset.crudesteel_edge) == flow(asset.steelscrap_edge))
        @add_balance(transform, :naturalgas, 0.2 * flow(asset.crudesteel_edge) == flow(asset.naturalgas_edge))
        @add_balance(transform, :carbonsource, 0.1 * flow(asset.crudesteel_edge) == flow(asset.carbonsource_edge))
        @add_balance(transform, :emissions, 0.3 * flow(asset.crudesteel_edge) == flow(asset.co2_edge))
    elseif style == :stoich
        @add_stoichiometric_balance(
            transform,
            :steel_production,
            0.5 * flow(asset.elec_edge)
            + 1.1 * flow(asset.steelscrap_edge)
            + 0.2 * flow(asset.naturalgas_edge)
            + 0.1 * flow(asset.carbonsource_edge)
            -->
            flow(asset.crudesteel_edge)
            + 0.3 * flow(asset.co2_edge),
            flow(asset.crudesteel_edge),
        )
    else
        error("Unsupported ElectricArcFurnace balance style: $style")
    end

    return (; system, asset)
end

function assert_eaf_solution(asset, model)
    expected_crudesteel = [1.0, 2.0, 3.0]
    expected_elec = [0.5, 1.0, 1.5]
    expected_scrap = [1.1, 2.2, 3.3]
    expected_naturalgas = [0.2, 0.4, 0.6]
    expected_carbonsource = [0.1, 0.2, 0.3]
    expected_co2 = [0.3, 0.6, 0.9]

    @test objective_value(model) ≈ 22.2 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.crudesteel_edge, t)) ≈ expected_crudesteel[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
        @test value(flow(asset.steelscrap_edge, t)) ≈ expected_scrap[t] atol = 1e-8
        @test value(flow(asset.naturalgas_edge, t)) ≈ expected_naturalgas[t] atol = 1e-8
        @test value(flow(asset.carbonsource_edge, t)) ≈ expected_carbonsource[t] atol = 1e-8
        @test value(flow(asset.co2_edge, t)) ≈ expected_co2[t] atol = 1e-8
    end
end

function test_asset_electricarcfurnace_balance()
    @testset "ElectricArcFurnace Small Solve Cases" begin
        add_balance_case = make_eaf_case(:add_balance)
        stoich_case = make_eaf_case(:stoich)

        add_balance_model = build_test_model(add_balance_case.system)
        stoich_model = build_test_model(stoich_case.system)

        assert_eaf_solution(add_balance_case.asset, add_balance_model)
        assert_eaf_solution(stoich_case.asset, stoich_model)

        for t in 1:3
            @test value(flow(add_balance_case.asset.crudesteel_edge, t)) ≈ value(flow(stoich_case.asset.crudesteel_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.elec_edge, t)) ≈ value(flow(stoich_case.asset.elec_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.steelscrap_edge, t)) ≈ value(flow(stoich_case.asset.steelscrap_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.naturalgas_edge, t)) ≈ value(flow(stoich_case.asset.naturalgas_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.carbonsource_edge, t)) ≈ value(flow(stoich_case.asset.carbonsource_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.co2_edge, t)) ≈ value(flow(stoich_case.asset.co2_edge, t)) atol = 1e-8
        end
        @test objective_value(add_balance_model) ≈ objective_value(stoich_model) atol = 1e-8
    end

    return nothing
end

test_asset_electricarcfurnace_balance()

end # module TestAssetElectricArcFurnaceBalance
