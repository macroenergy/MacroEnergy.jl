module TestAssetSyntheticAmmoniaBalance

using Test
using JuMP
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    @add_balance,
    Ammonia,
    Electricity,
    Hydrogen,
    Nitrogen,
    SyntheticAmmonia,
    flow,
    make

function make_syntheticammonia_case(style::Symbol)
    system = make_test_system([Hydrogen, Nitrogen, Electricity, Ammonia])

    h2_source = make_supply_node(Hydrogen, :h2_source, system.time_data[:Hydrogen], [2.0, 2.0, 2.0])
    n2_source = make_supply_node(Nitrogen, :n2_source, system.time_data[:Nitrogen], [3.0, 3.0, 3.0])
    elec_source = make_supply_node(Electricity, :elec_source, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    nh3_sink = make_demand_node(Ammonia, :nh3_sink, system.time_data[:Ammonia], [1.0, 2.0, 3.0])
    push_locations!(system, h2_source, n2_source, elec_source, nh3_sink)

    asset = make(
        SyntheticAmmonia,
        Dict{Symbol,Any}(
            :id => :synthetic_ammonia_test,
            :can_expand => false,
            :can_retire => false,
            :existing_capacity => 10.0,
            :h2_consumption => 0.5,
            :n2_consumption => 0.2,
            :electricity_consumption => 0.3,
            :h2_start_vertex => :h2_source,
            :n2_start_vertex => :n2_source,
            :elec_start_vertex => :elec_source,
            :nh3_end_vertex => :nh3_sink,
        ),
        system,
    )
    push!(system.assets, asset)

    transform = asset.synthetic_ammonia_transform
    if style == :add_balance
        transform.balance_data = Dict{Symbol,Any}()
        @add_balance(transform, :h2, 0.5 * flow(asset.nh3_edge) == flow(asset.h2_edge))
        @add_balance(transform, :n2, 0.2 * flow(asset.nh3_edge) == flow(asset.n2_edge))
        @add_balance(transform, :electricity, 0.3 * flow(asset.nh3_edge) == flow(asset.elec_edge))
    elseif style != :default
        error("Unsupported SyntheticAmmonia balance style: $style")
    end

    return (; system, asset)
end

function assert_syntheticammonia_solution(asset, model)
    expected_nh3 = [1.0, 2.0, 3.0]
    expected_h2 = [0.5, 1.0, 1.5]
    expected_n2 = [0.2, 0.4, 0.6]
    expected_elec = [0.3, 0.6, 0.9]

    @test objective_value(model) ≈ 11.4 atol = 1e-8
    for t in 1:3
        @test value(flow(asset.nh3_edge, t)) ≈ expected_nh3[t] atol = 1e-8
        @test value(flow(asset.h2_edge, t)) ≈ expected_h2[t] atol = 1e-8
        @test value(flow(asset.n2_edge, t)) ≈ expected_n2[t] atol = 1e-8
        @test value(flow(asset.elec_edge, t)) ≈ expected_elec[t] atol = 1e-8
    end
end

function test_asset_syntheticammonia_balance()
    @testset "SyntheticAmmonia Small Solve Cases" begin
        default_case = make_syntheticammonia_case(:default)
        add_balance_case = make_syntheticammonia_case(:add_balance)

        default_model = build_test_model(default_case.system)
        add_balance_model = build_test_model(add_balance_case.system)

        assert_syntheticammonia_solution(default_case.asset, default_model)
        assert_syntheticammonia_solution(add_balance_case.asset, add_balance_model)

        for t in 1:3
            @test value(flow(default_case.asset.nh3_edge, t)) ≈ value(flow(add_balance_case.asset.nh3_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.h2_edge, t)) ≈ value(flow(add_balance_case.asset.h2_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.n2_edge, t)) ≈ value(flow(add_balance_case.asset.n2_edge, t)) atol = 1e-8
            @test value(flow(default_case.asset.elec_edge, t)) ≈ value(flow(add_balance_case.asset.elec_edge, t)) atol = 1e-8
        end
        @test objective_value(default_model) ≈ objective_value(add_balance_model) atol = 1e-8
    end

    return nothing
end

test_asset_syntheticammonia_balance()

end # module TestAssetSyntheticAmmoniaBalance
