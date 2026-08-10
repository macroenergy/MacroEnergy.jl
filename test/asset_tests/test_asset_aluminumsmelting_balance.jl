module TestAssetAluminumSmeltingBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    @add_stoichiometric_balance,
    Aluminum,
    AluminumSmelting,
    Alumina,
    CO2,
    Electricity,
    Graphite,
    flow,
    make

function make_aluminumsmelting_case(style::Symbol)
    system = make_test_system([Electricity, Alumina, Graphite, Aluminum, CO2])

    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    alumina_source = make_supply_node(Alumina, :alumina_source, system.time_data[:Alumina], [2.0, 2.0, 2.0])
    graphite_source = make_supply_node(Graphite, :graphite_source, system.time_data[:Graphite], [3.0, 3.0, 3.0])
    aluminum_sink = make_demand_node(Aluminum, :aluminum_sink, system.time_data[:Aluminum], [1.0, 2.0, 3.0])
    co2_sink = make_free_node(CO2, :co2_sink, system.time_data[:CO2])
    push_locations!(system, elec_source, alumina_source, graphite_source, aluminum_sink, co2_sink)

    asset = make(
        AluminumSmelting,
        Dict{Symbol,Any}(
            :id => :aluminumsmelting_test,
            :timedata => "Aluminum",
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 10.0,
            :elec_aluminum_rate => 4.0,
            :alumina_aluminum_rate => 2.0,
            :graphite_aluminum_rate => 0.5,
            :graphite_emissions_rate => 2.0,
            :co2_sink => :co2_sink,
            :elec_start_vertex => :elec_source,
            :alumina_start_vertex => :alumina_source,
            :graphite_start_vertex => :graphite_source,
            :aluminum_end_vertex => :aluminum_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.aluminumsmelting_transform
    transform.balance_data = Dict{Symbol,Any}()

    if style == :add_balance
        @add_balance(transform, :electricity, 4.0 * flow(asset.aluminum_edge) == flow(asset.elec_edge))
        @add_balance(transform, :alumina, 2.0 * flow(asset.aluminum_edge) == flow(asset.alumina_edge))
        @add_balance(transform, :graphite, 0.5 * flow(asset.aluminum_edge) == flow(asset.graphite_edge))
        @add_balance(transform, :emissions, 1.0 * flow(asset.aluminum_edge) == flow(asset.co2_edge))
    elseif style == :stoich
        @add_stoichiometric_balance(
            transform,
            :aluminum_production,
            4.0 * flow(asset.elec_edge) + 2.0 * flow(asset.alumina_edge) + 0.5 * flow(asset.graphite_edge)
            -->
            flow(asset.aluminum_edge) + 1.0 * flow(asset.co2_edge),
            flow(asset.aluminum_edge),
        )
    else
        error("Unsupported aluminum smelting balance style: $style")
    end

    return (; system, asset)
end

function assert_aluminumsmelting_solution(asset, model)
    expected_aluminum = [1.0, 2.0, 3.0]
    expected_elec = [4.0, 8.0, 12.0]
    expected_alumina = [2.0, 4.0, 6.0]
    expected_graphite = [0.5, 1.0, 1.5]
    expected_co2 = [1.0, 2.0, 3.0]

    @test objective_value(model) ≈ 57.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.aluminum_edge, t)) ≈ expected_aluminum[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
        @test value(flow(asset.alumina_edge, t)) ≈ expected_alumina[t] atol = 1e-8
        @test value(flow(asset.graphite_edge, t)) ≈ expected_graphite[t] atol = 1e-8
        @test value(flow(asset.co2_edge, t)) ≈ expected_co2[t] atol = 1e-8
    end
end

function test_asset_aluminumsmelting_balance()
    @testset "AluminumSmelting Small Solve Cases" begin
        add_balance_case = make_aluminumsmelting_case(:add_balance)
        stoich_case = make_aluminumsmelting_case(:stoich)

        add_balance_model = build_test_model(add_balance_case.system)
        stoich_model = build_test_model(stoich_case.system)

        assert_aluminumsmelting_solution(add_balance_case.asset, add_balance_model)
        assert_aluminumsmelting_solution(stoich_case.asset, stoich_model)

        for t in 1:3
            @test value(flow(add_balance_case.asset.aluminum_edge, t)) ≈ value(flow(stoich_case.asset.aluminum_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.elec_edge, t)) ≈ value(flow(stoich_case.asset.elec_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.alumina_edge, t)) ≈ value(flow(stoich_case.asset.alumina_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.graphite_edge, t)) ≈ value(flow(stoich_case.asset.graphite_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.co2_edge, t)) ≈ value(flow(stoich_case.asset.co2_edge, t)) atol = 1e-8
        end
        @test objective_value(add_balance_model) ≈ objective_value(stoich_model) atol = 1e-8
    end

    return nothing
end

test_asset_aluminumsmelting_balance()

end # module TestAssetAluminumSmeltingBalance
