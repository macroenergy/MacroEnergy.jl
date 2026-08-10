module TestAssetAluminaPlantBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    @add_stoichiometric_balance,
    Alumina,
    AluminaPlant,
    Bauxite,
    CO2,
    Electricity,
    NaturalGas,
    flow,
    make

function make_aluminaplant_case(style::Symbol)
    system = make_test_system([Electricity, Bauxite, NaturalGas, Alumina, CO2])

    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    bauxite_source = make_supply_node(Bauxite, :bauxite_source, system.time_data[:Bauxite], [2.0, 2.0, 2.0])
    fuel_source = make_supply_node(NaturalGas, :fuel_source, system.time_data[:NaturalGas], [3.0, 3.0, 3.0])
    alumina_sink = make_demand_node(Alumina, :alumina_sink, system.time_data[:Alumina], [1.0, 2.0, 3.0])
    co2_sink = make_free_node(CO2, :co2_sink, system.time_data[:CO2])
    push_locations!(system, elec_source, bauxite_source, fuel_source, alumina_sink, co2_sink)

    asset = make(
        AluminaPlant,
        Dict{Symbol,Any}(
            :id => :aluminaplant_test,
            :timedata => "Alumina",
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 10.0,
            :elec_alumina_rate => 2.0,
            :bauxite_alumina_rate => 3.0,
            :fuel_alumina_rate => 1.0,
            :fuel_emissions_rate => 0.1,
            :co2_sink => :co2_sink,
            :elec_start_vertex => :elec_source,
            :bauxite_start_vertex => :bauxite_source,
            :fuel_start_vertex => :fuel_source,
            :alumina_end_vertex => :alumina_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.aluminaplant_transform
    transform.balance_data = Dict{Symbol,Any}()

    if style == :add_balance
        @add_balance(transform, :electricity, 2.0 * flow(asset.alumina_edge) == flow(asset.elec_edge))
        @add_balance(transform, :bauxite, 3.0 * flow(asset.alumina_edge) == flow(asset.bauxite_edge))
        @add_balance(transform, :fuel, 1.0 * flow(asset.alumina_edge) == flow(asset.fuel_edge))
        @add_balance(transform, :emissions, 0.1 * flow(asset.alumina_edge) == flow(asset.co2_edge))
    elseif style == :stoich
        @add_stoichiometric_balance(
            transform,
            :alumina_production,
            2.0 * flow(asset.elec_edge) + 3.0 * flow(asset.bauxite_edge) + 1.0 * flow(asset.fuel_edge)
            -->
            flow(asset.alumina_edge) + 0.1 * flow(asset.co2_edge),
            flow(asset.alumina_edge),
        )
    else
        error("Unsupported alumina plant balance style: $style")
    end

    return (; system, asset)
end

function assert_aluminaplant_solution(asset, model)
    expected_alumina = [1.0, 2.0, 3.0]
    expected_elec = [2.0, 4.0, 6.0]
    expected_bauxite = [3.0, 6.0, 9.0]
    expected_fuel = [1.0, 2.0, 3.0]
    expected_co2 = [0.1, 0.2, 0.3]

    @test objective_value(model) ≈ 66.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.alumina_edge, t)) ≈ expected_alumina[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
        @test value(flow(asset.bauxite_edge, t)) ≈ expected_bauxite[t] atol = 1e-8
        @test value(flow(asset.fuel_edge, t)) ≈ expected_fuel[t] atol = 1e-8
        @test value(flow(asset.co2_edge, t)) ≈ expected_co2[t] atol = 1e-8
    end
end

function test_asset_aluminaplant_balance()
    @testset "AluminaPlant Small Solve Cases" begin
        add_balance_case = make_aluminaplant_case(:add_balance)
        stoich_case = make_aluminaplant_case(:stoich)

        add_balance_model = build_test_model(add_balance_case.system)
        stoich_model = build_test_model(stoich_case.system)

        assert_aluminaplant_solution(add_balance_case.asset, add_balance_model)
        assert_aluminaplant_solution(stoich_case.asset, stoich_model)

        for t in 1:3
            @test value(flow(add_balance_case.asset.alumina_edge, t)) ≈ value(flow(stoich_case.asset.alumina_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.elec_edge, t)) ≈ value(flow(stoich_case.asset.elec_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.bauxite_edge, t)) ≈ value(flow(stoich_case.asset.bauxite_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.fuel_edge, t)) ≈ value(flow(stoich_case.asset.fuel_edge, t)) atol = 1e-8
            @test value(flow(add_balance_case.asset.co2_edge, t)) ≈ value(flow(stoich_case.asset.co2_edge, t)) atol = 1e-8
        end
        @test objective_value(add_balance_model) ≈ objective_value(stoich_model) atol = 1e-8
    end

    return nothing
end

test_asset_aluminaplant_balance()

end # module TestAssetAluminaPlantBalance
