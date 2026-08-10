module TestAssetElectricHeatingBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    ElectricHeating,
    Electricity,
    Heat,
    flow,
    make

function make_electricheating_case(style::Symbol)
    system = make_test_system([Electricity, Heat])

    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    heat_sink = make_demand_node(Heat, :heat_sink, system.time_data[:Heat], [2.0, 4.0, 6.0])
    push_locations!(system, elec_source, heat_sink)

    asset = make(
        ElectricHeating,
        Dict{Symbol,Any}(
            :id => :electric_heating_test,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 20.0,
            :elec_consumption => 0.5,
            :elec_start_vertex => :elec_source,
            :heat_end_vertex => :heat_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.heating_transform
    if style == :add_balance
        transform.balance_data = Dict{Symbol,Any}()
        @add_balance(transform, :energy, flow(asset.heat_edge) == 2.0 * flow(asset.elec_edge))
    elseif style != :default
        error("Unsupported ElectricHeating balance style: $style")
    end

    return (; system, asset)
end

function assert_electricheating_solution(asset, model)
    expected_heat = [2.0, 4.0, 6.0]
    expected_elec = [1.0, 2.0, 3.0]

    @test objective_value(model) ≈ 6.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.heat_edge, t)) ≈ expected_heat[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
    end
end

function test_asset_electricheating_balance()
    @testset "ElectricHeating Small Solve Cases" begin
        default_case = make_electricheating_case(:default)
        add_balance_case = make_electricheating_case(:add_balance)

        default_model = build_test_model(default_case.system)
        add_balance_model = build_test_model(add_balance_case.system)

        assert_electricheating_solution(default_case.asset, default_model)
        assert_electricheating_solution(add_balance_case.asset, add_balance_model)

        for t in 1:3
            @test value(flow(default_case.asset.heat_edge, t)) ≈ value(flow(add_balance_case.asset.heat_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.elec_edge, t)) ≈ value(flow(add_balance_case.asset.elec_edge, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(add_balance_model) atol = 1e-8
    end

    return nothing
end

test_asset_electricheating_balance()

end # module TestAssetElectricHeatingBalance
