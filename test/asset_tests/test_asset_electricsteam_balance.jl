module TestAssetElectricSteamBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    ElectricSteam,
    Electricity,
    Steam,
    flow,
    make

function make_electricsteam_case(style::Symbol)
    system = make_test_system([Electricity, Steam])

    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    steam_sink = make_demand_node(Steam, :steam_sink, system.time_data[:Steam], [2.0, 4.0, 6.0])
    push_locations!(system, elec_source, steam_sink)

    asset = make(
        ElectricSteam,
        Dict{Symbol,Any}(
            :id => :electric_steam_test,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 20.0,
            :elec_consumption => 0.5,
            :elec_start_vertex => :elec_source,
            :steam_end_vertex => :steam_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.steam_transform
    if style == :add_balance
        transform.balance_data = Dict{Symbol,Any}()
        @add_balance(transform, :energy, flow(asset.steam_edge) == 2.0 * flow(asset.elec_edge))
    elseif style != :default
        error("Unsupported ElectricSteam balance style: $style")
    end

    return (; system, asset)
end

function assert_electricsteam_solution(asset, model)
    expected_steam = [2.0, 4.0, 6.0]
    expected_elec = [1.0, 2.0, 3.0]

    @test objective_value(model) ≈ 6.0 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.steam_edge, t)) ≈ expected_steam[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
    end
end

function test_asset_electricsteam_balance()
    @testset "ElectricSteam Small Solve Cases" begin
        default_case = make_electricsteam_case(:default)
        add_balance_case = make_electricsteam_case(:add_balance)

        default_model = build_test_model(default_case.system)
        add_balance_model = build_test_model(add_balance_case.system)

        assert_electricsteam_solution(default_case.asset, default_model)
        assert_electricsteam_solution(add_balance_case.asset, add_balance_model)

        for t in 1:3
            @test value(flow(default_case.asset.steam_edge, t)) ≈ value(flow(add_balance_case.asset.steam_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.elec_edge, t)) ≈ value(flow(add_balance_case.asset.elec_edge, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(add_balance_model) atol = 1e-8
    end

    return nothing
end

test_asset_electricsteam_balance()

end # module TestAssetElectricSteamBalance
