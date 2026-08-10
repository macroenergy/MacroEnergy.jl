module TestAssetDirectReductionElectricArcFurnaceBalance

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
    DirectReductionElectricArcFurnace,
    Electricity,
    IronOre,
    NaturalGas,
    flow,
    make

function make_dreaf_case(style::Symbol)
    system = make_test_system([IronOre, Electricity, NaturalGas, Coal, CrudeSteel, CO2])

    ironore_source = make_supply_node(IronOre, :ironore_source, system.time_data[:IronOre], [2.0, 2.0, 2.0])
    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    reductant_source = make_supply_node(NaturalGas, :reductant_source, system.time_data[:NaturalGas], [3.0, 3.0, 3.0])
    carbonsource_source = make_supply_node(Coal, :carbonsource_source, system.time_data[:Coal], [4.0, 4.0, 4.0])
    crudesteel_sink = make_demand_node(CrudeSteel, :crudesteel_sink, system.time_data[:CrudeSteel], [1.0, 2.0, 3.0])
    co2_sink = make_free_node(CO2, :co2_sink, system.time_data[:CO2])
    push_locations!(system, ironore_source, elec_source, reductant_source, carbonsource_source, crudesteel_sink, co2_sink)

    asset = make(
        DirectReductionElectricArcFurnace,
        Dict{Symbol,Any}(
            :id => :dreaf_test,
            :transforms => Dict{Symbol,Any}(
                :timedata => "CrudeSteel",
                :ironore_consumption => 1.1,
                :electricity_consumption => 0.5,
                :reductant_consumption => 0.4,
                :carbonsource_consumption => 0.2,
                :emission_rate => 0.3,
            ),
            :edges => Dict{Symbol,Any}(
                :reductant_edge => Dict{Symbol,Any}(:commodity => "NaturalGas"),
                :carbonsource_edge => Dict{Symbol,Any}(:commodity => "Coal"),
                :crudesteel_edge => Dict{Symbol,Any}(
                    :can_expand => false,
                    :can_retire => false,
                    :existing_capacity => 10.0,
                ),
            ),
            :co2_sink => :co2_sink,
            :ironore_start_vertex => :ironore_source,
            :elec_start_vertex => :elec_source,
            :reductant_start_vertex => :reductant_source,
            :carbonsource_start_vertex => :carbonsource_source,
            :crudesteel_end_vertex => :crudesteel_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.dreaf_transform
    transform.balance_data = Dict{Symbol,Any}()

    if style == :add_balance
        @add_balance(transform, :ironore, 1.1 * flow(asset.crudesteel_edge) == flow(asset.ironore_edge))
        @add_balance(transform, :electricity, 0.5 * flow(asset.crudesteel_edge) == flow(asset.elec_edge))
        @add_balance(transform, :reductant, 0.4 * flow(asset.crudesteel_edge) == flow(asset.reductant_edge))
        @add_balance(transform, :carbonsource, 0.2 * flow(asset.crudesteel_edge) == flow(asset.carbonsource_edge))
        @add_balance(transform, :emissions, 0.3 * flow(asset.crudesteel_edge) == flow(asset.co2_edge))
    elseif style == :stoich
        @add_stoichiometric_balance(
            transform,
            :steel_production,
            1.1 * flow(asset.ironore_edge)
            + 0.5 * flow(asset.elec_edge)
            + 0.4 * flow(asset.reductant_edge)
            + 0.2 * flow(asset.carbonsource_edge)
            -->
            flow(asset.crudesteel_edge)
            + 0.3 * flow(asset.co2_edge),
            flow(asset.crudesteel_edge),
        )
    else
        error("Unsupported DREAF balance style: $style")
    end

    return (; system, asset)
end

function assert_dreaf_solution(asset, model)
    expected_crudesteel = [1.0, 2.0, 3.0]
    expected_ironore = [1.1, 2.2, 3.3]
    expected_elec = [0.5, 1.0, 1.5]
    expected_reductant = [0.4, 0.8, 1.2]
    expected_carbonsource = [0.2, 0.4, 0.6]
    expected_co2 = [0.3, 0.6, 0.9]

    @test objective_value(model) ≈ 28.2 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.crudesteel_edge, t)) ≈ expected_crudesteel[t] atol = 1e-8
        @test value(flow(asset.ironore_edge, t)) ≈ expected_ironore[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
        @test value(flow(asset.reductant_edge, t)) ≈ expected_reductant[t] atol = 1e-8
        @test value(flow(asset.carbonsource_edge, t)) ≈ expected_carbonsource[t] atol = 1e-8
        @test value(flow(asset.co2_edge, t)) ≈ expected_co2[t] atol = 1e-8
    end
end

function test_asset_dreaf_balance()
    @testset "DirectReductionElectricArcFurnace Small Solve Cases" begin
        add_balance_case = make_dreaf_case(:add_balance)
        stoich_case = make_dreaf_case(:stoich)

        add_balance_model = build_test_model(add_balance_case.system)
        stoich_model = build_test_model(stoich_case.system)

        assert_dreaf_solution(add_balance_case.asset, add_balance_model)
        assert_dreaf_solution(stoich_case.asset, stoich_model)

        for t in 1:3
            @test value(flow(add_balance_case.asset.crudesteel_edge, t)) ≈ value(flow(stoich_case.asset.crudesteel_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.ironore_edge, t)) ≈ value(flow(stoich_case.asset.ironore_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.elec_edge, t)) ≈ value(flow(stoich_case.asset.elec_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.reductant_edge, t)) ≈ value(flow(stoich_case.asset.reductant_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.carbonsource_edge, t)) ≈ value(flow(stoich_case.asset.carbonsource_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.co2_edge, t)) ≈ value(flow(stoich_case.asset.co2_edge, t)) atol = 1e-8
        end
        @test objective_value(add_balance_model) ≈ objective_value(stoich_model) atol = 1e-8
    end

    return nothing
end

test_asset_dreaf_balance()

end # module TestAssetDirectReductionElectricArcFurnaceBalance
