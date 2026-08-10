module TestAssetFuelCellBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    Electricity,
    FuelCell,
    Hydrogen,
    flow,
    make

function make_fuelcell_case(style::Symbol)
    system = make_test_system([Hydrogen, Electricity])

    h2_source = make_supply_node(Hydrogen, :h2_source, system.time_data[:Hydrogen], [2.0, 2.0, 2.0])
    elec_sink = make_demand_node(Electricity, :elec_sink, system.time_data[:Electricity], [1.0, 2.0, 3.0])
    push_locations!(system, h2_source, elec_sink)

    asset = make(
        FuelCell,
        Dict{Symbol,Any}(
            :id => :fuelcell_test,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 10.0,
            :efficiency_rate => 0.5,
            :h2_start_vertex => :h2_source,
            :elec_end_vertex => :elec_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.fuelcell_transform
    if style == :add_balance
        transform.balance_data = Dict{Symbol,Any}()
        @add_balance(transform, :energy, flow(asset.elec_edge) == 0.5 * flow(asset.h2_edge))
    elseif style != :default
        error("Unsupported FuelCell balance style: $style")
    end

    return (; system, asset)
end

function assert_fuelcell_solution(asset, model)
    expected_elec = [1.0, 2.0, 3.0]
    expected_h2 = [2.0, 4.0, 6.0]

    @test objective_value(model) ≈ 24.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
        @test value(flow(asset.h2_edge, t)) ≈ expected_h2[t] atol = 1e-8
    end
end

function test_asset_fuelcell_balance()
    @testset "FuelCell Small Solve Cases" begin
        default_case = make_fuelcell_case(:default)
        add_balance_case = make_fuelcell_case(:add_balance)

        default_model = build_test_model(default_case.system)
        add_balance_model = build_test_model(add_balance_case.system)

        assert_fuelcell_solution(default_case.asset, default_model)
        assert_fuelcell_solution(add_balance_case.asset, add_balance_model)

        for t in 1:3
            @test value(flow(default_case.asset.elec_edge, t)) ≈ value(flow(add_balance_case.asset.elec_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.h2_edge, t)) ≈ value(flow(add_balance_case.asset.h2_edge, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(add_balance_model) atol = 1e-8
    end

    return nothing
end

test_asset_fuelcell_balance()

end # module TestAssetFuelCellBalance
