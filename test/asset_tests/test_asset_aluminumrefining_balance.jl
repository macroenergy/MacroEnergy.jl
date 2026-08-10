module TestAssetAluminumRefiningBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    @add_stoichiometric_balance,
    Aluminum,
    AluminumRefining,
    AluminumScrap,
    Electricity,
    flow,
    make

function make_aluminumrefining_case(style::Symbol)
    system = make_test_system([Electricity, AluminumScrap, Aluminum])

    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    scrap_source = make_supply_node(AluminumScrap, :scrap_source, system.time_data[:AluminumScrap], [2.0, 2.0, 2.0])
    aluminum_sink = make_demand_node(Aluminum, :aluminum_sink, system.time_data[:Aluminum], [1.0, 2.0, 3.0])
    push_locations!(system, elec_source, scrap_source, aluminum_sink)

    asset = make(
        AluminumRefining,
        Dict{Symbol,Any}(
            :id => :aluminumrefining_test,
            :timedata => "Aluminum",
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 10.0,
            :elec_aluminum_rate => 1.5,
            :aluminumscrap_aluminum_rate => 0.5,
            :elec_start_vertex => :elec_source,
            :aluminumscrap_start_vertex => :scrap_source,
            :aluminum_end_vertex => :aluminum_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.aluminum_transform
    transform.balance_data = Dict{Symbol,Any}()

    if style == :add_balance
        @add_balance(transform, :electricity, 1.5 * flow(asset.aluminum_edge) == flow(asset.elec_edge))
        @add_balance(transform, :scrap, 0.5 * flow(asset.aluminum_edge) == flow(asset.aluminumscrap_edge))
    elseif style == :stoich
        @add_stoichiometric_balance(
            transform,
            :aluminum_production,
            1.5 * flow(asset.elec_edge) + 0.5 * flow(asset.aluminumscrap_edge)
            -->
            flow(asset.aluminum_edge),
            flow(asset.aluminum_edge),
        )
    else
        error("Unsupported aluminum refining balance style: $style")
    end

    return (; system, asset)
end

function assert_aluminumrefining_solution(asset, model)
    expected_aluminum = [1.0, 2.0, 3.0]
    expected_elec = [1.5, 3.0, 4.5]
    expected_scrap = [0.5, 1.0, 1.5]

    @test objective_value(model) ≈ 15.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.aluminum_edge, t)) ≈ expected_aluminum[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
        @test value(flow(asset.aluminumscrap_edge, t)) ≈ expected_scrap[t] atol = 1e-8
    end
end

function test_asset_aluminumrefining_balance()
    @testset "AluminumRefining Small Solve Cases" begin
        add_balance_case = make_aluminumrefining_case(:add_balance)
        stoich_case = make_aluminumrefining_case(:stoich)

        add_balance_model = build_test_model(add_balance_case.system)
        stoich_model = build_test_model(stoich_case.system)

        assert_aluminumrefining_solution(add_balance_case.asset, add_balance_model)
        assert_aluminumrefining_solution(stoich_case.asset, stoich_model)

        for t in 1:3
            @test value(flow(add_balance_case.asset.aluminum_edge, t)) ≈ value(flow(stoich_case.asset.aluminum_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.elec_edge, t)) ≈ value(flow(stoich_case.asset.elec_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.aluminumscrap_edge, t)) ≈ value(flow(stoich_case.asset.aluminumscrap_edge, t)) atol = 1e-8
        end
        @test objective_value(add_balance_model) ≈ objective_value(stoich_model) atol = 1e-8
    end

    return nothing
end

test_asset_aluminumrefining_balance()

end # module TestAssetAluminumRefiningBalance
